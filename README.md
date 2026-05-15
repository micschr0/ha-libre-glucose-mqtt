# ha-libre-glucose-mqtt — Home Assistant app repository

> ⚠️ **Not affiliated with, endorsed by, or sponsored by Abbott
> Laboratories.** Unofficial research and self-hosting tool. Use may
> violate Abbott's LibreLink Up Terms of Service. No warranty. Not for
> medical decisions, therapy, dosing, or diagnosis. Use at your own
> risk.

This repository ships a single Home Assistant Supervisor **app** (formerly
known as an *add-on* — HA's developer docs renamed the concept in 2025):
**Libre Glucose MQTT Bridge** polls glucose readings from LibreLink Up
and publishes them to your Home Assistant MQTT broker with automatic
sensor discovery.

Under the hood it runs [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs),
a Rust service designed for this exact bridge use case. This repository
is just a thin Home Assistant wrapper around the upstream image — no
custom code lives here besides the app manifest, a small Bash entrypoint,
and documentation.

## Install

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
   (Yes, HA's UI still says "Add-on Store" in many places — the
   developer docs led the rename to "app", the user-facing UI is
   migrating gradually.)
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add the repository URL:
   ```
   https://github.com/micschr0/ha-libre-glucose-mqtt
   ```
4. Refresh the store; **Libre Glucose MQTT Bridge** appears under a new
   section with this repository's name.
5. Click it → **Install**. Configure it, then **Start**.

## Requirements

- Home Assistant OS or Supervised (Supervisor is required — HA
  Container installations cannot run apps).
- The official **Mosquitto broker** app installed and the MQTT
  integration configured. The app refuses to start without an MQTT
  service.
- A LibreLink Up account with at least one active connection (typically
  a family-share invitation from a Libre 2 / Libre 3 sensor wearer).

## Architecture

```text
LibreLink Up  ──►  Libre Glucose MQTT Bridge app  ──►  Mosquitto  ──►  HA entities
                   (runs gluco-hub-rs container)
```

## Supported platforms

`amd64`, `aarch64`. RPi 3 in 64-bit mode works; 32-bit-only platforms
(`armv7`, `armhf`, `i386`) are not supported in V1 — track upstream
[gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs/issues) for
armv7 builds.

## Trademarks

LibreLink, LibreView, FreeStyle Libre, and Libre 2 / Libre 3 are
trademarks of Abbott. This project is not affiliated with, endorsed
by, or sponsored by Abbott Laboratories.

## Licence

AGPL-3.0-or-later — see `LICENSE`. Consistent with the upstream
`gluco-hub-rs` licence.
