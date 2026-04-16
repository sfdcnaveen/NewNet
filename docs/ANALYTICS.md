# Analytics (Privacy-Friendly)

NewNet sends only anonymous product events:

- `app_installed` (first launch)
- `app_opened`
- `feature_used`

## Data Model

- `distinct_id`: random local UUID generated once and stored in `UserDefaults`
- `event`: one of the event names above
- `timestamp`: ISO-8601 UTC timestamp
- `properties`: minimal metadata (`app_version`, `build_number`, `platform`, and feature name where applicable)

## What We Do Not Collect

- No personal data
- No device fingerprinting
- No file content from downloads

## Endpoint

Set `AnalyticsEndpointURL` in target `Info.plist` settings (Xcode build setting `INFOPLIST_KEY_AnalyticsEndpointURL`) to your HTTPS endpoint.

Example payload:

```json
{
  "event": "feature_used",
  "distinct_id": "2f9d4db0-4e88-4f73-96cf-bf80d779d89c",
  "timestamp": "2026-04-03T12:00:00Z",
  "properties": {
    "feature": "download_queued",
    "app_version": "1.0",
    "build_number": "1",
    "platform": "macOS"
  }
}
```

## Runtime Behavior

- Events are queued to disk in Application Support.
- Flush is async, retried with exponential backoff.
- If offline or endpoint is unavailable, events stay queued.
- Users can disable analytics in Settings; disabling clears queued events.
