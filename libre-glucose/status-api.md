# HTTP Status API

The HTTP Status API is served by the upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs) binary, which binds to `0.0.0.0:8080` (set via `GLUCO_HUB__HTTP__BIND` in `run.sh`). This add-on only wires HA Ingress (`ingress: true`, `ingress_port: 8080` in `config.yaml`) to that listener.

Routes are **not** directly reachable from the host — all requests go through the authenticated HA Supervisor Ingress proxy. You access them via the add-on's panel in the HA UI, or through the Supervisor-issued Ingress URL.

## Data endpoints

These three routes power the [Clock View](clock-view.md). They are not protected by Bearer auth.

### `GET /clock/state`

Returns a JSON snapshot of the latest glucose reading. The Clock View fetches this once at startup to populate the display before the SSE stream delivers its first event.

```json
{
  "mgdl": 112,
  "trend": "Flat",
  "ts": 1750000000000,
  "delta": 2,
  "patient": "Alex"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `mgdl` | integer | Glucose value in mg/dL |
| `trend` | string | One of: `DoubleDown`, `SingleDown`, `FortyFiveDown`, `Flat`, `FortyFiveUp`, `SingleUp`, `DoubleUp`, `NotComputable`, `OutOfRange` |
| `ts` | integer | Unix timestamp in milliseconds |
| `delta` | integer | Change since previous reading (mg/dL), may be `null` |
| `patient` | string | Display name, may be absent |

### `GET /clock/events`

Server-Sent Events stream. The Clock View opens an `EventSource` connection to this endpoint for live updates.

**Named events:**

| Event | Payload | Description |
|-------|---------|-------------|
| `reading` | JSON (same shape as `/clock/state`) | New glucose reading arrived |
| `keepalive` | _(empty)_ | Periodic heartbeat to keep the connection alive |

**Query parameters:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `eink` | `1` | Hint to the server that the client is an e-ink display. Set automatically by the Clock View when it detects e-ink mode (`?eink` or `?preset=eink`). |

Example connection:

```
GET /clock/events?eink=1
Accept: text/event-stream
```

The Clock View reconnects automatically with exponential back-off (2 s → 30 s cap) on any connection error.

### `GET /clock/history`

Returns a JSON array of recent readings used to seed the Clock View's sparkline on first load. This call is best-effort — the Clock View swallows any error silently and draws the sparkline from SSE events only if history is unavailable.

```json
[
  { "ts": 1749999940000, "mgdl": 108 },
  { "ts": 1750000000000, "mgdl": 112 }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `ts` | integer | Unix timestamp in milliseconds |
| `mgdl` | integer | Glucose value in mg/dL |

The array covers approximately the last 3 hours (up to 180 points at 1-minute intervals).

## Caching

All data endpoint responses carry `Cache-Control: no-store`. This prevents browsers and intermediate proxies from ever serving a stale glucose value — every request goes to the live server.

## Other endpoints

The following endpoints are confirmed from the upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs) README:

| Path | Auth | Response |
|------|------|----------|
| `GET /healthz` | public | `{"status":"ok","version":"…"}` |
| `GET /metrics` | public | Prometheus text exposition format |
| `GET /glucose/latest` | optional Bearer | Latest cached reading, or `503` + `API001` if no reading is available |

**Bearer auth:** set `GLUCO_HUB__HTTP__BEARER_TOKEN` in the add-on configuration to require a token for `/glucose/*` routes. The `/healthz` and `/metrics` endpoints remain public regardless.

**`X-Disclaimer` header:** every response from gluco-hub-rs carries `X-Disclaimer: not-for-medical-use` — the canonical machine-readable disclaimer signal.

**`GET /glucose/latest` response shape (upstream-confirmed):**

```json
{
  "patient_id": "00000000-0000-0000-0000-000000000000",
  "source_id": "llu",
  "timestamp": "2025-01-01T12:00:00Z",
  "glucose_mgdl": 112,
  "trend": "Flat"
}
```

Note: the `/clock/*` routes use an internal shape (`mgdl`, `ts` as Unix-ms, `delta`, `patient`) optimised for the Clock View, while `/glucose/latest` uses the public API shape (`glucose_mgdl`, ISO 8601 `timestamp`, `patient_id`).

For the full and authoritative endpoint list, see the upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs) documentation.

## See also

- [Clock View](clock-view.md) — the visual display that consumes the data endpoints documented here
- [Configuration](configuration.md) — add-on options including `poll_interval_secs`, `glucose_unit`, and `topic_prefix`

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.
