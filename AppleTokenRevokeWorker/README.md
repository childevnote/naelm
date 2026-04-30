# Apple Token Revoke Worker

Serverless endpoint to exchange and revoke Sign in with Apple tokens using Cloudflare Workers + KV (free tier).

## What this does

- `POST /apple/store-token`: exchanges `authorizationCode` for tokens and stores the `refresh_token` in KV.
- `POST /apple/revoke`: revokes the stored `refresh_token` (or exchanges a provided `authorizationCode` then revokes).

## Requirements

- Cloudflare Workers account (free tier is OK)
- Apple Sign in key (`.p8`) with Key ID
- Apple Team ID and Client ID (bundle ID for native apps)

## Setup

1) Create a KV namespace

```bash
cd /Users/kdj/GitHub/naelm/AppleTokenRevokeWorker
wrangler kv:namespace create apple_token_kv
```

2) Update `wrangler.toml` with the namespace ID.

3) Set secrets

```bash
cd /Users/kdj/GitHub/naelm/AppleTokenRevokeWorker
wrangler secret put APPLE_CLIENT_ID
wrangler secret put APPLE_TEAM_ID
wrangler secret put APPLE_KEY_ID
wrangler secret put APPLE_PRIVATE_KEY
```

4) Run tests

```bash
cd /Users/kdj/GitHub/naelm/AppleTokenRevokeWorker
npm test
```

5) Deploy

```bash
cd /Users/kdj/GitHub/naelm/AppleTokenRevokeWorker
wrangler deploy
```

## API

### POST /apple/store-token

```json
{
  "userID": "apple-user-id",
  "authorizationCode": "code-from-apple"
}
```

### POST /apple/revoke

```json
{
  "userID": "apple-user-id",
  "authorizationCode": "optional-code"
}
```

## Notes

- The authorization code expires quickly. The best flow is to call `/apple/store-token` immediately after sign-in.
- The worker stores refresh tokens using a SHA-256 hash of `userID` as the KV key.
