import test from "node:test";
import assert from "node:assert/strict";
import { handleRequest } from "../src/index.mjs";

test("returns 400 on invalid json", async () => {
  const request = new Request("http://localhost/apple/revoke", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "not-json",
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

  assert.equal(response.status, 400);
  const body = await response.json();
  assert.equal(body.error, "Invalid JSON");
});
