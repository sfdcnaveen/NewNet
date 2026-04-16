CREATE TABLE IF NOT EXISTS analytics_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event TEXT NOT NULL,
  distinct_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  properties_json TEXT NOT NULL,
  received_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_analytics_events_received_at
ON analytics_events(received_at);

CREATE INDEX IF NOT EXISTS idx_analytics_events_event
ON analytics_events(event);
