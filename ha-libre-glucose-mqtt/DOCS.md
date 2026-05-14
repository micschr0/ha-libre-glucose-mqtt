# Libre Glucose MQTT Bridge — Documentation

## What it does

This add-on runs [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs)
in a container alongside Home Assistant. Every `poll_interval_secs`
(default 60 s) it:

1. Logs in to LibreLink Up using the configured credentials.
2. Fetches the latest glucose reading for the selected patient.
3. Publishes the reading to the HA MQTT broker (Mosquitto) on
   `<topic_prefix>/glucose` (default `gluco-hub/ha/glucose`).
4. Publishes an MQTT-discovery config message so Home Assistant
   auto-creates a sensor entity called **Glucose**.

If the MQTT broker is unreachable, readings are queued in
`/data/state` (persistent across add-on restarts and updates) and
flushed on reconnect. Up to 10 000 readings — about 35 days at the
default 5-minute LibreLink Up update raster — can be buffered.

## Configuration reference

| Option | Type | Default | Description |
|---|---|---|---|
| `llu_email` | string | *required* | LibreLink Up account email. |
| `llu_password` | string | *required* | LibreLink Up account password. Stored only in the add-on options DB; never written to MQTT or logs. |
| `llu_region` | enum | `EU` | LibreLink Up regional API endpoint. Match your account — wrong region returns auth errors. Supported: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `US`, `LA`, `RU`, `CN`. |
| `llu_patient_id` | string | *empty* | If your account has multiple connections (e.g. multiple kids), set this to the specific patient's id. Empty = first connection. |
| `llu_timezone` | IANA TZ | `UTC` | The patient's local timezone. LibreLink Up returns timestamps in local wall-clock time; without this hint they appear shifted by your offset. Examples: `Europe/Berlin`, `America/New_York`. |
| `poll_interval_secs` | int (30–600) | `60` | How often to ask LibreLink Up for new readings. LibreLink Up itself only updates every ~60 seconds, so values below 30 waste API calls. |
| `device_name` | string | *empty* | Friendly device name in HA. Empty falls back to `Gluco Hub (<client_id>)`. |
| `topic_prefix` | string | `gluco-hub/ha` | MQTT topic prefix. Readings publish to `<prefix>/glucose`. |
| `client_id` | string | `gluco-hub-ha` | MQTT client id (1–23 chars, alphanumeric / `-` / `_`). Also appears in the HA discovery unique-id. |
| `log_level` | enum | `info` | Logging verbosity. `debug` is useful for troubleshooting LibreLink Up issues. |

## What the sensor exposes

State: current glucose in **mg/dL** (this is hard-coded upstream for V1;
a future upstream patch will make mmol/L selectable for European users —
the JSON payload already carries both units).

Attributes (on the sensor entity):

| Attribute | Description |
|---|---|
| `mgdl` | Reading in mg/dL. |
| `mmol` | Reading in mmol/L. |
| `trend` | Trend arrow: `DoubleDown`, `SingleDown`, `FortyFiveDown`, `Flat`, `FortyFiveUp`, `SingleUp`, `DoubleUp`, `NotComputable`, or `OutOfRange`. |
| `timestamp` | ISO-8601 timestamp of the reading (UTC). |
| `patient_id` | The LibreLink Up patient identifier this reading is for. |

## MQTT topics

| Topic | Direction | Retained | Purpose |
|---|---|---|---|
| `<topic_prefix>/glucose` | publish | no | Latest reading (JSON). |
| `<topic_prefix>/_health` | publish | yes | Liveness: `{"online": true/false}`. Used by HA's availability_topic to grey out the entity when the bridge is offline. |
| `<topic_prefix>/_stats` | publish | yes | Per-minute summary of polls / sink success / DLQ depth. Useful for dashboards. |
| `homeassistant/sensor/gluco_hub_<client_id>_glucose/config` | publish | yes | HA MQTT-discovery config message. Auto-published after every reconnect. |

## Troubleshooting

**Add-on refuses to start with `No MQTT service available`.**
Install the official **Mosquitto broker** add-on and configure the MQTT
HA-integration (Settings → Devices & Services → Add Integration →
MQTT). Then restart this add-on.

**Sensor entity never appears in HA.**
- Confirm Mosquitto is running and reachable.
- Set `log_level` to `debug` and check the add-on log for an
  `mqtt sink configured` entry and `discovery_enabled = true`.
- Check the discovery topic with the **MQTT** add-on's *Listen to topic*
  feature: `homeassistant/sensor/+/config`. The bridge's discovery
  message should appear within ~10 seconds of starting the add-on.

**LibreLink Up login fails with `[LLU003]`.**
Wrong credentials, wrong region, or your password contains characters
the add-on UI escaped incorrectly. Double-check region (it's the one
on your *LibreView* account, which may not match your physical
location).

**Sensor values look wrong / time-shifted.**
Set `llu_timezone` to the patient's IANA timezone (e.g.
`Europe/Berlin`). LibreLink Up returns timestamps in local wall-clock
time without an offset — `UTC` is only correct if the patient lives in
UTC.

**My platform is not in the install dropdown.**
V1 supports `amd64` and `aarch64` only. 32-bit ARM (`armv7`, `armhf`)
and `i386` are blocked by the upstream gluco-hub build configuration —
follow [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs) for
status.

## Disclaimer

**This add-on is not a medical device.** It is a research and
self-hosting tool. Do not use the values it reports for therapy
decisions, insulin dosing, or diagnosis. The upstream `gluco-hub-rs`
binary prints a `NOT FOR MEDICAL USE` banner on every start — see
`SCOPE.md`, `DISCLAIMER.md`, and `LICENSE` in the upstream repository.

## Architecture notes

```text
LibreLink Up API
       │ HTTPS
       ▼
┌──────────────────────────────────────┐
│ ha-libre-glucose-mqtt add-on         │
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
   Mosquitto add-on
       │
       ▼
   Home Assistant entities
```

## Reporting issues

For add-on-specific problems (manifest, install, run.sh): file an issue
at [ha-libre-glucose-mqtt](https://github.com/micschr0/ha-libre-glucose-mqtt/issues).

For polling / MQTT / LibreLink Up logic: file upstream at
[gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs/issues).
