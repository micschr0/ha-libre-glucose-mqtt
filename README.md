# ha-libre-glucose-mqtt — Home Assistant Add-on Repository

> ⚠️ **Not for medical use.** Research and self-hosting tool. No warranty.
> Not for therapy, dosing, or diagnosis. See the add-on `DOCS.md` for full
> disclaimer.

This repository ships a single Home Assistant Supervisor add-on:
**Libre Glucose MQTT Bridge** — polls glucose readings from LibreLink Up
and publishes them to your Home Assistant MQTT broker with automatic
sensor discovery.

Under the hood it runs [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs),
a Rust service designed for this exact bridge use case. This repository
is just a thin Home Assistant wrapper around the upstream image — no
custom code lives here besides the add-on manifest, a small Bash
entrypoint, and documentation.

## Install

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add the repository URL:
   ```
   https://github.com/micschr0/ha-libre-glucose-mqtt
   ```
4. Refresh the store; the add-on **Libre Glucose MQTT Bridge** appears
   under a new section with this repository's name.
5. Click the add-on → **Install**. Configure it, then **Start**.

## Requirements

- Home Assistant OS or Supervised (Supervisor required — Container
  installations do not support add-ons).
- The official **Mosquitto broker** add-on installed and the MQTT
  integration set up. The add-on will refuse to start without an MQTT
  service.
- A LibreLink Up account with at least one connection (typically a
  family-share invitation from a Libre 2/3 sensor wearer).

## Architecture

```text
LibreLink Up  ──►  ha-libre-glucose-mqtt add-on  ──►  Mosquitto  ──►  HA entities
                   (runs gluco-hub-rs container)
```

## Supported Platforms

`amd64`, `aarch64`. RPi 3 in 64-bit mode works; 32-bit-only platforms
(`armv7`, `armhf`, `i386`) are not supported in V1 — track upstream
[gluco-hub-rs #TBD](https://github.com/micschr0/gluco-hub-rs/issues) for
armv7 builds.

## Trademarks

LibreLink, LibreView, FreeStyle Libre, and Libre 2/3 are trademarks of
Abbott. This project is not affiliated with, endorsed by, or sponsored
by Abbott Laboratories.

## Licence

AGPL-3.0-or-later — see `LICENSE`. Consistent with the upstream
`gluco-hub-rs` licence.
