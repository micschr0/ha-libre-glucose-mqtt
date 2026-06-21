# Libre Glucose MQTT Bridge — Documentation

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
| `poll_interval_secs` | int (30–600) | `60` | Poll interval in seconds. Values below 30 waste API calls; LibreLink Up updates every ~60 s. |
| `device_name` | string | — | Friendly device name in HA. Defaults to `Gluco Hub (<client_id>)`. |
| `topic_prefix` | string | `gluco-hub/ha` | MQTT topic prefix. Readings publish to `<prefix>/glucose`. |
| `client_id` | string | `ha` | MQTT client ID (1–23 chars, alphanumeric / `-` / `_`). Appears in the HA discovery unique ID. |
| `log_level` | enum | `info` | Log verbosity. Use `debug` to troubleshoot LibreLink Up issues. |

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

## Clock View

The app serves a glucose display at the Ingress path `/clock`, accessible from the HA sidebar.

| Route | Description |
|---|---|
| `/clock` | HTML display. Query params: `?lo=70&hi=180`, `?eink=1`, `?unit=mgdl\|mmol`, `?dark=0\|1`. |
| `/clock/state` | JSON snapshot of the current reading. |
| `/clock/events` | Server-Sent Events stream. |

Display layout is detected from the viewport — no URL parameter needed:

| Class | Condition | Shows |
|---|---|---|
| `wall` | longest edge > 900 px | value + name + trend + time |
| `phone` | default | standard layout |
| `small` | < 400 px | value + trend |
| `watch` | < 200 px | value + background color |

**E-ink mode** (`?eink=1`): the SSE stream throttles to changes > 1 mg/dL or gaps > 5 min; the page replaces the opacity decay and hypo pulse with a `STALE Xm Ys` label.

All Clock View responses send `Cache-Control: no-store`.

## Troubleshooting

**App refuses to start — `No MQTT service available`.**
Install the **Mosquitto broker** app and configure the MQTT integration (Settings → Devices & Services → Add Integration → MQTT). Then restart this app.

**Sensor never appears.**
1. Confirm Mosquitto is running.
2. Set `log_level: debug` and look for `mqtt sink configured` and `discovery_enabled = true` in the log.
3. Use MQTT's *Listen to topic* feature: subscribe to `homeassistant/sensor/+/config`. The discovery message should arrive within ~10 seconds of starting.

**LibreLink Up login fails with `[LLU003]`.**
Wrong credentials, wrong region, or the password was escaped incorrectly by the HA UI. The region must match your LibreView account, not your physical location.

**Sensor values are time-shifted.**
Set `llu_timezone` to the patient's IANA timezone (e.g. `Europe/Berlin`). LibreLink Up timestamps are in local wall-clock time with no UTC offset.

**My platform is not in the install dropdown.**
V1 supports `amd64` and `aarch64`. 32-bit ARM (`armv7`, `armhf`) and `i386` are not supported — follow [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs) for status.

## Disclaimer

**Not affiliated with Abbott Laboratories.** This app polls LibreLink Up without any partnership with Abbott. Use may violate Abbott's Terms of Service.

**Not a medical device.** Do not use readings for medical decisions, insulin dosing, diagnosis, or any clinical purpose.

**No warranty.** The software is provided as-is. The maintainers accept no liability for missed readings, incorrect data, or any other consequences.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.

<details>
<summary>Architecture</summary>

```text
LibreLink Up API
       │ HTTPS
       ▼
┌──────────────────────────────────────┐
│ libre-glucose app                    │
│  ┌────────────────────────────────┐  │
│  │ run.sh (bashio)                │  │
│  │  • read /data/options.json     │  │
│  │  • bashio::services mqtt       │  │
│  │  • export GLUCO_HUB__*         │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ /usr/local/bin/gluco-hub run   │  │
│  │  LLU-Source → MQTT-Sink (+DLQ) │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
       │ MQTT (plaintext, internal)
       ▼
   Mosquitto app
       │
       ▼
   Home Assistant entities
```

This app is a thin Bash wrapper around [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs). No polling or MQTT logic lives here — only the HA manifest, `run.sh`, and this documentation.

</details>
