<!-- doc-review: 2026-07-16 -->

<!-- ACC-01 audit 2026-06-23: 13/13 config.yaml options covered; closed gaps: llu_version, glucose_unit, llu_accounts -->

# Configuration

Configure the add-on by setting the three required fields — `llu_email`, `llu_password`, `llu_region` — and the **Glucose** sensor entity `sensor.gluco_hub_<client_id>_glucose` will appear in Home Assistant.

> **Sensor entity naming.** Your sensor entity ID is `sensor.gluco_hub_<client_id>_glucose`. With the default `client_id: ha`, that is `sensor.gluco_hub_ha_glucose`. Use this ID in every automation and dashboard card.

## Architecture

The polling, MQTT publishing, MQTT discovery, and persistent retry queue are all implemented by the upstream [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs) binary. **This add-on configures and runs that binary** — it provides the `config.yaml` schema, the `run.sh` entrypoint, and HA Ingress wiring. No polling or MQTT logic lives in this repository.

> **Don't paste your password into a troubleshooting trace.** The add-on never logs it; if you see it in a log, that is a bug — open an issue.

> [!NOTE]
> For every option below, default values are chosen so that a fresh install works once you provide `llu_email`, `llu_password`, and `llu_region`.

## Configuration

### Quick reference

| Option | Type | Default | Description |
|---|---|---|---|
| `llu_email` | string | *required* | LibreLink Up account email. |
| `llu_password` | string | *required* | LibreLink Up account password. Never written to MQTT or logs. |
| `llu_region` | enum | `EU` | Regional API endpoint. Must match your LibreView account region, not your physical location. |
| `llu_patient_id` | string | — | Patient UUID. Leave empty to use the first connection. |
| `llu_timezone` | IANA TZ | `UTC` | Patient's local timezone. Without this, timestamps appear shifted. Example: `Europe/Berlin`. |
| `llu_version` | string | — | LibreLink Up app-version header sent to the API. Leave empty to use the upstream default. |
| `poll_interval_secs` | int (30–600) | `60` | Poll interval in seconds. |
| `device_name` | string | — | Friendly device name in HA. Defaults to `Gluco Hub (<client_id>)`. |
| `glucose_unit` | enum | `mgdl` | Sensor state unit: `mgdl` for mg/dL, `mmol` for mmol/L. |
| `topic_prefix` | string | `gluco-hub/ha` | MQTT topic prefix. Readings publish to `<prefix>/glucose`. |
| `client_id` | string | `ha` | MQTT client ID (1–23 chars). Appears in the HA discovery unique ID. |
| `llu_accounts` | list | `[]` | Named multi-account/multi-patient sources. See [multi-account setup](multi-account.md). |
| `log_level` | enum | `info` | Log verbosity. Use `debug` to troubleshoot. |

### Per-option reference

#### `llu_email`

**Required.** LibreLink Up account email. The account that holds the family-share invitation. No default — the add-on refuses to start without this.

Example: `anna@example.com`.

#### `llu_password`

**Required.** LibreLink Up account password. Stored only in the add-on options database; never written to MQTT or logs. No default.

Example: `correct-horse-battery-staple`.

#### `llu_region`

Regional API endpoint. **Must match your LibreView account region** — not your physical location. Default: `EU`.

Valid values: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `US`, `LA`, `RU`, `CN`.

> **Don't set `llu_region` to your physical country.** Use the region of your LibreView account — they often differ. If unsure, open the LibreView app; the region is shown under **Account settings**.

#### `llu_patient_id`

Patient UUID. Required only if your account has multiple connections. Leave empty to use the first connection.

#### `llu_timezone`

IANA timezone name of the sensor wearer. Default: `UTC`. LibreLink Up timestamps are local wall-clock time with no UTC offset; without this, your readings appear time-shifted.

Example: `Europe/Berlin`.

#### `llu_version`

LibreLink Up app-version header sent to the API. Leave empty to use the upstream default. Override only as a last resort when upstream's default is no longer accepted.

#### `poll_interval_secs`

Poll interval in seconds. Range: 30–600. Default: `60`. Values below 30 waste API calls; LibreLink Up updates every ~60 s.

> **Don't set `poll_interval_secs` below 30.** LibreLink Up updates roughly every 60 seconds; faster polling wastes your API quota and can trigger rate limits.

#### `device_name`

Friendly device name shown in Home Assistant. Empty falls back to `Gluco Hub (<client_id>)`.

#### `glucose_unit`

Sensor state unit: `mgdl` for mg/dL, `mmol` for mmol/L. Default: `mgdl`. In multi-account mode (`llu_accounts`) this option does not affect MQTT discovery — discovery always advertises mg/dL regardless.

#### `topic_prefix`

MQTT topic prefix. Default: `gluco-hub/ha`. Readings publish to `<prefix>/glucose`. With the default, your reading topic is `gluco-hub/ha/glucose`.

#### `client_id`

MQTT client ID. 1–23 characters, alphanumeric, `-`, or `_`. Default: `ha`. Appears in the HA discovery unique ID — changing it orphans previously published entities. In multi-account mode (`llu_accounts`), this option is ignored and `client_id = "ha"` is hard-coded.

> **Don't set `client_id` in multi-account mode.** The generated TOML hard-codes `client_id = "ha"` and the option is silently ignored.

#### `llu_accounts`

List of named LibreLink Up sources for multi-account polling. Default: `[]` (empty). When non-empty, supersedes the single-account `llu_*` fields above. Full schema and a worked example are on the [multi-account setup](multi-account.md) page.

> **Don't mix `llu_accounts` with single-account `llu_*` fields.** When `llu_accounts` is non-empty, the single-account fields above are superseded and any value you set there is ignored.

#### `log_level`

Log verbosity. Default: `info`. Use `debug` when troubleshooting LibreLink Up issues. Valid values: `trace`, `debug`, `info`, `warn`, `error`.

## Sensor

The **Glucose** sensor appears under the **Gluco Hub** device in Home Assistant (Settings → Devices & Services → MQTT).

**State:** current reading in mg/dL (or mmol/L if configured).

**Attributes:**

| Attribute | Description |
|---|---|
| `mgdl` | Reading in mg/dL. |
| `mmol` | Reading in mmol/L. |
| `trend` | Trend arrow: `DoubleDown`, `SingleDown`, `FortyFiveDown`, `Flat`, `FortyFiveUp`, `SingleUp`, `DoubleUp`, `NotComputable`, or `OutOfRange`. |
| `timestamp` | ISO-8601 timestamp (UTC). |
| `patient_id` | LibreLink Up patient identifier. |

## MQTT topics

With the default `topic_prefix: gluco-hub/ha`, the topics are:

| Topic | Retained | Purpose |
|---|---|---|
| `gluco-hub/ha/glucose` | no | Latest reading (JSON). |
| `gluco-hub/ha/_health` | yes | Liveness: `{"online": true/false}`. Used as `availability_topic`. |
| `gluco-hub/ha/_stats` | yes | Per-minute poll/sink summary. Useful for dashboards. |
| `gluco-hub/ha/_patients` | yes | Patient list. JSON array of `{id, display_name, is_active}`. `display_name` is abbreviated (e.g. `Anna M.`). |
| `homeassistant/sensor/gluco_hub_ha_glucose/config` | yes | HA MQTT discovery config. Published after every reconnect. |

For non-default `topic_prefix` and `client_id`, substitute `<prefix>` and `<client_id>` respectively:

- Reading: `<prefix>/glucose`
- Discovery: `homeassistant/sensor/gluco_hub_<client_id>_glucose/config`

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.