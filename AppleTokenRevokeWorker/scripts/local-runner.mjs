import { handleRequest } from "../src/index.mjs";

const request = new Request("http://localhost/apple/revoke", {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({}),
});

const response = await handleRequest(request, {
  APPLE_CLIENT_ID: "example.bundle.id",
  APPLE_TEAM_ID: "TEAMID1234",
  APPLE_KEY_ID: "KEYID1234",
  APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nREPLACE\n-----END PRIVATE KEY-----",
  APPLE_TOKEN_KV: {
    get: async () => null,
    put: async () => {},
    delete: async () => {},
  },
});

console.log("status", response.status);
console.log(await response.text());
