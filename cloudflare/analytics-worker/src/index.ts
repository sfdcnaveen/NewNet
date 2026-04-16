export interface Env {
  DB: D1Database;
}

type EventName = "app_installed" | "app_opened" | "feature_used";

interface IngestPayload {
  event: EventName;
  distinct_id: string;
  timestamp: string;
  properties?: Record<string, string>;
}

const ALLOWED_EVENTS = new Set<EventName>([
  "app_installed",
  "app_opened",
  "feature_used",
]);

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true }, 200);
    }

    if (request.method !== "POST" || url.pathname !== "/v1/events") {
      return json({ error: "not_found" }, 404);
    }

    let payload: IngestPayload;
    try {
      payload = (await request.json()) as IngestPayload;
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    const validationError = validatePayload(payload);
    if (validationError) {
      return json({ error: validationError }, 400);
    }

    const properties = payload.properties ?? {};

    await env.DB
      .prepare(
        `INSERT INTO analytics_events (event, distinct_id, timestamp, properties_json)
         VALUES (?1, ?2, ?3, ?4)`
      )
      .bind(
        payload.event,
        payload.distinct_id,
        payload.timestamp,
        JSON.stringify(properties)
      )
      .run();

    return json({ ok: true }, 202);
  },
};

function validatePayload(payload: Partial<IngestPayload>): string | null {
  if (!payload || typeof payload !== "object") {
    return "invalid_payload";
  }

  if (!payload.event || !ALLOWED_EVENTS.has(payload.event as EventName)) {
    return "invalid_event";
  }

  if (typeof payload.distinct_id !== "string" || payload.distinct_id.length < 8 || payload.distinct_id.length > 128) {
    return "invalid_distinct_id";
  }

  if (typeof payload.timestamp !== "string" || Number.isNaN(Date.parse(payload.timestamp))) {
    return "invalid_timestamp";
  }

  if (payload.properties !== undefined) {
    if (typeof payload.properties !== "object" || payload.properties === null) {
      return "invalid_properties";
    }

    for (const [key, value] of Object.entries(payload.properties)) {
      if (typeof key !== "string" || typeof value !== "string") {
        return "invalid_properties";
      }

      if (key.length > 64 || value.length > 512) {
        return "invalid_properties";
      }
    }
  }

  return null;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}
