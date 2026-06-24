![Libre Glucose MQTT Bridge](assets/logo.png)

# Libre Glucose MQTT Bridge

A Home Assistant add-on that polls your **LibreLink Up** glucose readings and publishes them to MQTT with automatic sensor discovery — your **Glucose** sensor appears in Home Assistant within minutes of starting the add-on. Powered by [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs).

```admonish danger
**Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott.
```

[Get started](configuration.md)

## Why use it?

Abbott's apps lock your glucose data inside LibreLink Up. This add-on turns that reading into **a normal Home Assistant sensor** — an entity you fully control:

- **Automations & alerts** — notify, flash a light, or sound an alarm on highs and lows, with your own thresholds and quiet hours.
- **Dashboards & history** — chart your glucose beside everything else in your home, with long-term history stored locally.
- **Your data, your home** — the reading stays on your own broker and HA instance. No cloud dashboard, no subscription, no third party.
- **Build on it** — as an MQTT entity, the reading drives Node-RED, scripts, voice assistants, and any other integration.
- **Set-and-forget** — auto-discovery creates the sensor, the add-on reconnects on its own, and missed readings queue, then flush when the connection returns.

The add-on is a thin, auditable wrapper around the open-source [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs): all polling and MQTT logic lives upstream in gluco-hub-rs.

## Install

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add:
   ```
   https://github.com/micschr0/ha-libre-glucose-mqtt
   ```
4. Refresh the store; **Libre Glucose MQTT Bridge** appears in a new section.
5. Click it → **Install**. Enter your LibreLink Up email and password (and your **region**, if outside the `EU` default), then **Start**.

## Requirements

| Requirement | Notes |
|---|---|
| **Home Assistant OS or Supervised** | Supervisor required; Container installs cannot run add-ons. |
| **Mosquitto broker** add-on + **MQTT** integration | The add-on requires an MQTT service to start. |
| **LibreLink Up account** | At least one active connection (typically a family-share invitation from a Libre 2 or Libre 3 sensor wearer). |
| **Architecture** | `amd64`, `aarch64` (RPi 3 in 64-bit works). 32-bit ARM (`armv7`, `armhf`) and `i386` are not supported. |

## Your sensor

Once running, the add-on creates a **Glucose** sensor under the **Gluco Hub** device (Settings → Devices & Services → MQTT). The state holds the current reading in mg/dL by default (mmol/L if you configure it); entity attributes carry the full payload — mg/dL, mmol/L, trend arrow, and timestamp.

For every option, the sensor attributes, and MQTT topics, see [Configuration](configuration.md). For troubleshooting and architecture detail, see [Troubleshooting](troubleshooting.md).

## Getting help

- Add-on-specific issues (install, configuration, run): [ha-libre-glucose-mqtt issues](https://github.com/micschr0/ha-libre-glucose-mqtt/issues)
- Polling / MQTT / LibreLink Up logic: [gluco-hub-rs issues](https://github.com/micschr0/gluco-hub-rs/issues)
