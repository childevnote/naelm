const JSON_HEADERS = { "content-type": "application/json; charset=utf-8" };

export default {
  fetch: (request, env, ctx) => handleRequest(request, env, ctx),
};

export async function handleRequest(request, env) {
  const { pathname } = new URL(request.url);

  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method Not Allowed" });
  }

  if (pathname === "/apple/store-token") {
    return handleStoreToken(request, env);
  }

  if (pathname === "/apple/revoke") {
    return handleRevoke(request, env);
  }

  return jsonResponse(404, { error: "Not Found" });
}

async function handleStoreToken(request, env) {
  const body = await parseJson(request);
  if (!body) {
    return jsonResponse(400, { error: "Invalid JSON" });
  }

  const { userID, authorizationCode } = body;
  if (!userID || !authorizationCode) {
    return jsonResponse(400, { error: "Missing userID or authorizationCode" });
  }

  const tokenResponse = await exchangeAuthorizationCode(authorizationCode, env);
  if (!tokenResponse.ok) {
    return jsonResponse(502, { error: "Apple token exchange failed", details: tokenResponse.error });
  }

  if (!tokenResponse.refreshToken) {
    return jsonResponse(502, { error: "Apple did not return refresh_token" });
  }

  const key = await tokenStoreKey(userID);
  await env.APPLE_TOKEN_KV.put(key, tokenResponse.refreshToken);

  return jsonResponse(200, { stored: true });
}

async function handleRevoke(request, env) {
  const body = await parseJson(request);
  if (!body) {
    return jsonResponse(400, { error: "Invalid JSON" });
  }

  const { userID, authorizationCode } = body;
  if (!userID) {
    return jsonResponse(400, { error: "Missing userID" });
  }

  const key = await tokenStoreKey(userID);
  let refreshToken = await env.APPLE_TOKEN_KV.get(key);

  if (!refreshToken && authorizationCode) {
    const tokenResponse = await exchangeAuthorizationCode(authorizationCode, env);
    if (!tokenResponse.ok) {
      return jsonResponse(502, { error: "Apple token exchange failed", details: tokenResponse.error });
    }
    refreshToken = tokenResponse.refreshToken || "";
  }

  if (!refreshToken) {
    return jsonResponse(404, { error: "No refresh token available" });
  }

  const revokeResult = await revokeToken(refreshToken, env);
  if (!revokeResult.ok) {
    return jsonResponse(502, { error: "Apple revoke failed", details: revokeResult.error });
  }

  await env.APPLE_TOKEN_KV.delete(key);
  return jsonResponse(200, { revoked: true });
}

async function exchangeAuthorizationCode(code, env) {
  const clientSecret = await createClientSecret(env);
  const body = new URLSearchParams({
    client_id: env.APPLE_CLIENT_ID,
    client_secret: clientSecret,
    grant_type: "authorization_code",
    code,
  });

  const response = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!response.ok) {
    const error = await safeReadText(response);
    return { ok: false, error };
  }

  const payload = await response.json();
  return {
    ok: true,
    refreshToken: payload.refresh_token,
    accessToken: payload.access_token,
  };
}

async function revokeToken(token, env) {
  const clientSecret = await createClientSecret(env);
  const body = new URLSearchParams({
    client_id: env.APPLE_CLIENT_ID,
    client_secret: clientSecret,
    token,
    token_type_hint: "refresh_token",
  });

  const response = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!response.ok) {
    const error = await safeReadText(response);
    return { ok: false, error };
  }

  return { ok: true };
}

async function createClientSecret(env) {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: env.APPLE_TEAM_ID,
    iat: now,
    exp: now + 300,
    aud: "https://appleid.apple.com",
    sub: env.APPLE_CLIENT_ID,
  };

  const header = {
    alg: "ES256",
    kid: env.APPLE_KEY_ID,
    typ: "JWT",
  };

  const encodedHeader = base64urlEncode(JSON.stringify(header));
  const encodedPayload = base64urlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const key = await importPrivateKey(env.APPLE_PRIVATE_KEY);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput)
  );

  const encodedSignature = base64urlEncodeBytes(new Uint8Array(signature));
  return `${signingInput}.${encodedSignature}`;
}

async function importPrivateKey(pem) {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }

  return crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

async function tokenStoreKey(userID) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(userID)
  );
  return `refresh:${toHex(new Uint8Array(digest))}`;
}

function base64urlEncode(value) {
  const bytes = new TextEncoder().encode(value);
  return base64urlEncodeBytes(bytes);
}

function base64urlEncodeBytes(bytes) {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function toHex(bytes) {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function parseJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

async function safeReadText(response) {
  try {
    return await response.text();
  } catch {
    return "";
  }
}

function jsonResponse(status, body) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}
