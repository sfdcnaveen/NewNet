# Cloudflare Worker Analytics Setup (Free)

This sets up a minimal endpoint for NewNet analytics:

- `POST /v1/events` (ingest)
- `GET /health` (status)

Worker code lives in `cloudflare/analytics-worker`.

## 1) Prerequisites

- Cloudflare account
- Node.js 20+

## 2) Login and install deps

```bash
cd /Users/nn/Desktop/internetManager/NewNet/cloudflare/analytics-worker
npm install
npx wrangler login
```

## 3) Create D1 database

```bash
npx wrangler d1 create newnet_analytics
```

Copy the `database_id` from the output and set it in:

- `cloudflare/analytics-worker/wrangler.toml`

```toml
[[d1_databases]]
binding = "DB"
database_name = "newnet_analytics"
database_id = "YOUR_DATABASE_ID"
```

## 4) Apply schema migration

```bash
npx wrangler d1 migrations apply newnet_analytics
```

## 5) Deploy worker

```bash
npx wrangler deploy
```

After deploy, note your URL (example):

- `https://newnet-analytics.<subdomain>.workers.dev`

Endpoint for app config:

- `https://newnet-analytics.<subdomain>.workers.dev/v1/events`

## 6) Wire NewNet to endpoint

Set `INFOPLIST_KEY_AnalyticsEndpointURL` in both Debug/Release build settings to:

- `https://newnet-analytics.<subdomain>.workers.dev/v1/events`

(Defined in `NewNet.xcodeproj/project.pbxproj`.)

## 7) Test endpoint

```bash
curl -i -X POST "https://newnet-analytics.<subdomain>.workers.dev/v1/events" \
  -H "Content-Type: application/json" \
  -d '{
    "event":"app_opened",
    "distinct_id":"11111111-2222-3333-4444-555555555555",
    "timestamp":"2026-04-16T12:00:00Z",
    "properties":{"app_version":"1.1.3","platform":"macOS"}
  }'
```

Expected response: `202` with `{"ok":true}`.

Health check:

```bash
curl -i "https://newnet-analytics.<subdomain>.workers.dev/health"
```

## 8) Inspect data

```bash
npx wrangler d1 execute newnet_analytics --remote --command "SELECT id,event,distinct_id,received_at FROM analytics_events ORDER BY id DESC LIMIT 20"
```

## 9) Live logs

```bash
npx wrangler tail
```

## Event schema accepted by worker

```json
{
  "event": "app_installed|app_opened|feature_used",
  "distinct_id": "uuid-string",
  "timestamp": "ISO8601 UTC string",
  "properties": {
    "key": "value"
  }
}
```
