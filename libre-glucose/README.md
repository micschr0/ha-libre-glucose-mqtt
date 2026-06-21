# Libre Glucose MQTT Bridge

Polls LibreLink Up glucose readings every 60 seconds (configurable) and publishes them to Home Assistant via MQTT with auto-discovery — your sensor entity appears under **Settings → Devices & Services → MQTT** within minutes of starting the app.

Powered by [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs). This app is a thin Bash wrapper around the upstream Rust binary — no polling or MQTT logic lives here.

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

## Requirements

- The official **Mosquitto broker** app installed and the **MQTT** integration configured. The app refuses to start without an MQTT service.
- A LibreLink Up account with at least one active connection (typically a family-share invitation from a Libre 2 or Libre 3 sensor wearer).

## Configuration

See the **Configuration** tab in the HA UI, or the **Documentation** tab for the full reference. The two required fields are your LibreLink Up email and password; everything else has sensible defaults.

## Sensor entity

Once running, look for a **Glucose** sensor under the **Gluco Hub** device in Home Assistant. The state is the current reading in mg/dL; the full JSON payload (mmol/L, trend arrow, timestamp, patient ID) is available as entity attributes.

## Trademarks

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott. This project is not affiliated with Abbott Laboratories.

## Licence

AGPL-3.0-or-later.
