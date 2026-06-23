<!-- ACC-01 audit 2026-06-23: 13/13 config.yaml options covered; closed gaps: llu_version, glucose_unit, llu_accounts -->

# Configuration

## What it does

Every `poll_interval_secs` seconds (default: 60), the app:

1. Logs in to LibreLink Up with the configured credentials.
2. Fetches the latest glucose reading for the selected patient.
3. Publishes the reading to Mosquitto on `<topic_prefix>/glucose`.
4. Publishes an MQTT discovery message so Home Assistant creates a **Glucose** sensor automatically.

Readings that fail to publish queue in `/data/state` (persistent across restarts) and flush on reconnect. The queue holds up to 10,000 readings — about 35 days at LibreLink Up's default 5-minute update interval.

## Configuration

| Option | Type | Default | Description |
|---|---|---|---|
| `llu_email` | string | *required* | LibreLink Up account email. |
| `llu_password` | string | *required* | LibreLink Up account password. Never written to MQTT or logs. |
| `llu_region` | enum | `EU` | Regional API endpoint. Must match your LibreView account region, not your physical location. Options: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `LA`, `RU`, `US`, `CN`. |
| `llu_patient_id` | string | — | Patient UUID. Required only if your account has multiple connections. Leave empty to use the first connection. |
| `llu_timezone` | IANA TZ | `UTC` | The patient's local timezone. LibreLink Up timestamps are in local wall-clock time with no UTC offset; without this, times appear shifted. Example: `Europe/Berlin`. |
| `llu_version` | string | — | LibreLink Up app-version header sent to the API. Leave empty to use the upstream default. |
| `poll_interval_secs` | int (30–600) | `60` | Poll interval in seconds. Values below 30 waste API calls; LibreLink Up updates every ~60 s. |
| `device_name` | string | — | Friendly device name in HA. Defaults to `Gluco Hub (<client_id>)`. |
| `glucose_unit` | enum | `mgdl` | Sensor state unit: `mgdl` for mg/dL, `mmol` for mmol/L. |
| `topic_prefix` | string | `gluco-hub/ha` | MQTT topic prefix. Readings publish to `<prefix>/glucose`. |
| `client_id` | string | `ha` | MQTT client ID (1–23 chars, alphanumeric / `-` / `_`). Appears in the HA discovery unique ID. |
| `llu_accounts` | list | `[]` | Named multi-account/multi-patient sources. When non-empty, supersedes the single-account `llu_*` fields above. Full schema and a worked example are covered on the multi-account page (Phase 8). |
| `log_level` | enum | `info` | Log verbosity. Use `debug` to troubleshoot LibreLink Up issues. Options: `trace`, `debug`, `info`, `warn`, `error`. |

## Sensor

The **Glucose** sensor appears under the **Gluco Hub** device in Home Assistant (Settings → Devices & Services → MQTT).

State: current reading in mg/dL (or mmol/L if configured).

Attributes:

| Attribute | Description |
|---|---|
| `mgdl` | Reading in mg/dL. |
| `mmol` | Reading in mmol/L. |
| `trend` | Trend arrow: `DoubleDown`, `SingleDown`, `FortyFiveDown`, `Flat`, `FortyFiveUp`, `SingleUp`, `DoubleUp`, `NotComputable`, or `OutOfRange`. |
| `timestamp` | ISO-8601 timestamp (UTC). |
| `patient_id` | LibreLink Up patient identifier. |

## MQTT topics

| Topic | Retained | Purpose |
|---|---|---|
| `<prefix>/glucose` | no | Latest reading (JSON). |
| `<prefix>/_health` | yes | Liveness: `{"online": true/false}`. Used as `availability_topic`. |
| `<prefix>/_stats` | yes | Per-minute poll/sink summary. Useful for dashboards. |
| `<prefix>/_patients` | yes | Patient list. JSON array of `{id, display_name, is_active}`. `display_name` is abbreviated (e.g. `Anna M.`). Published after each successful login. |
| `homeassistant/sensor/gluco_hub_<client_id>_glucose/config` | yes | HA MQTT discovery config. Published after every reconnect. |

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.
