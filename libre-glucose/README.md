# Libre Glucose MQTT Bridge

Polls LibreLink Up glucose readings every 60 seconds (configurable) and
publishes them to Home Assistant via the MQTT broker, with full
auto-discovery — your sensor entity appears under **Settings → Devices
& Services → MQTT** within minutes of starting the app.

Powered by [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs).
This app is a thin Bash + Docker wrapper around the upstream Rust
binary — no business logic lives here.

> ⚠️ **Not for medical use.** Research and self-hosting tool. No
> warranty. Not for therapy, dosing, or diagnosis. See `DOCS.md` →
> *Disclaimer*.

## Requirements

- The official **Mosquitto broker** app installed and the **MQTT**
  Home Assistant integration configured. This app refuses to start
  without an MQTT service.
- A LibreLink Up account with at least one active connection
  (typically a family-share invitation from someone wearing a Libre 2
  or Libre 3 sensor).

## Configuration

See the **Configuration** tab in the HA UI, or `DOCS.md` for the full
reference. The two required fields are your LibreLink Up email and
password; everything else has sensible defaults.

## Sensor entity

Once running, look for an entity named **Glucose** under the **Gluco
Hub (gluco-hub-ha)** device in Home Assistant. The state is the
current reading in mg/dL; the full JSON payload (mmol/L, trend arrow,
timestamp, patient id) is available as entity attributes.

## Trademarks

LibreLink, LibreView, FreeStyle Libre, and Libre 2 / Libre 3 are
trademarks of Abbott. This project is not affiliated with, endorsed
by, or sponsored by Abbott Laboratories.

## Licence

AGPL-3.0-or-later.
