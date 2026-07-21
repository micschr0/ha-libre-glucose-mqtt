<!-- doc-review: 2026-07-21 -->

# Libre Glucose MQTT Bridge

Polls LibreLink Up glucose readings every 60 seconds (configurable) and publishes them to Home Assistant via MQTT with auto-discovery — your sensor entity appears under **Settings → Devices & Services → MQTT** within minutes of starting the add-on.

Powered by [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs). This add-on is a thin Bash wrapper around the upstream Rust binary — no polling or MQTT logic lives here.

## Quick start

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add:
   ```
   https://github.com/micschr0/ha-libre-glucose-mqtt
   ```
4. Refresh the store; **Libre Glucose MQTT Bridge** appears in a new section.
5. Click it → **Install**. Configure, then **Start**.

## Requirements

- **Home Assistant OS or Supervised.** Container installations cannot run add-ons.
- The official **Mosquitto broker** add-on installed and started, with the **MQTT integration** configured. The add-on refuses to start without an MQTT service.
- A **LibreLink Up account** with at least one active connection — typically a family-share invitation from a Libre 2 or Libre 3 sensor wearer.

## Supported platforms

`amd64`, `aarch64`. RPi 3 in 64-bit mode works. 32-bit ARM (`armv7`, `armhf`) and `i386` are not supported.

## Configuration

Three fields are required. Fill them, leave everything else on defaults, then click **Start**.

| Field | Example | Notes |
|---|---|---|
| `llu_email` | `anna@example.com` | The account that holds the family-share invitation. |
| `llu_password` | `correct-horse-battery-staple` | Stored only in the add-on options; never written to MQTT or logs. |
| `llu_region` | `EU` | Must match your **LibreView account region** — not your physical country. |

Valid regions: `AE`, `AP`, `AU`, `CA`, `DE`, `EU`, `EU2`, `FR`, `JP`, `US`, `LA`, `RU`, `CN`.

> **Don't set `llu_region` to your physical country.** Use the region of your LibreView account — they often differ. If unsure, open the LibreView app; the region is shown under **Account settings**.

Two optional fields worth setting now:

- **`llu_timezone`** — IANA timezone of the sensor wearer, e.g. `Europe/Berlin`. Without this, timestamps appear shifted by your UTC offset.
- **`poll_interval_secs`** — leave at `60` unless you have a reason. LibreLink Up updates every ~60 s; lower values waste API quota.

> **Don't set `poll_interval_secs` below 30.** Faster polling wastes your API quota and can trigger rate limits.

For every other option see the **Configuration** tab in the HA UI or the full [Configuration reference](https://micschr0.github.io/ha-libre-glucose-mqtt/configuration.html).

## Sensor entity

Once running, look for a **Glucose** sensor under the **Gluco Hub** device in Home Assistant. The state is the current reading in mg/dL; the full JSON payload (mmol/L, trend arrow, timestamp, patient ID) is available as entity attributes.

The sensor entity ID is **`sensor.gluco_hub_ha_glucose`** by default. If you changed `client_id`, replace `ha` with your value.

## Trademarks

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott. This project is not affiliated with Abbott Laboratories.

## Licence

AGPL-3.0-or-later.

---

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.
