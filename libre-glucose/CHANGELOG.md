# Changelog

All notable changes to this app are documented here. Versioning follows
the upstream [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs)
CalVer scheme (`YYYY.0M0D.PATCH`) so the app version always names the
gluco-hub release it bundles.

## [Unreleased]

### Changed

- **Slug renamed** `ha-libre-glucose-mqtt` → `libre-glucose`. The repo
  folder, `config.yaml`'s `slug:`, and the AppArmor profile name all
  match the new value. Path nesting in the repo is now half as deep
  (`libre-glucose/config.yaml` instead of
  `ha-libre-glucose-mqtt/ha-libre-glucose-mqtt/config.yaml`).
  Risk-free because the repo is still private — no installed
  Supervisor has a `/data/options.json` keyed by the old slug.
- **Terminology** in user-facing prose (`README.md`, `DOCS.md`,
  `CHANGELOG.md`) switched from "add-on" to "app" to match HA
  developer docs' 2025 rename. Schema fields in `config.yaml`,
  CI action names (`frenck/action-addon-linter`), and references to
  HA's official `home-assistant/addons` repo intentionally keep the
  legacy "add-on" / "addon" naming — those have not been renamed
  upstream.

### Added

- `.gitignore` at repo root (OS / editor / Python cruft).
- `SECURITY.md` at repo root, routing security reports between this
  wrapper and the upstream `gluco-hub-rs` repo.
- Initial release: thin wrapper around `ghcr.io/micschr0/gluco-hub`,
  shipping a Dockerfile that lays the upstream binary onto a HA Debian
  base image, plus a `bashio` entrypoint that maps app options and
  the Mosquitto MQTT service info into `GLUCO_HUB__*` environment
  variables.
- Supported platforms: `amd64`, `aarch64`.
- MQTT auto-discovery enabled by default — sensor entity appears under
  the **Glucose Hub** device within ~10 seconds of starting.
- Persistent DLQ at `/data/state` survives app restarts and updates.
- Custom AppArmor profile (`apparmor.txt`) confines the app to
  outbound HTTPS + MQTT and `/data` writes; capabilities are dropped to
  the minimum needed. Earns +1 on the Supervisor security rating
  (target rating: 6/6).
- HA UI assets: `icon.png` (128×128), `logo.png` (250×100),
  English + German translation files for all options.
- Liveness probe via Supervisor watchdog
  (`tcp://[HOST]:[PORT:8080]`) — the app auto-restarts on socket
  hang.
- CI: `frenck/action-addon-linter`, `yamllint`, `hadolint`,
  `shellcheck` run on every PR.
- Renovate config tracks the upstream `gluco-hub` image tag and the HA
  Debian base images.

### Known limitations

- Sensor unit is hard-coded to mg/dL upstream; mmol/L users see the
  reading under the `mmol` JSON attribute. A future upstream patch
  (`MqttSinkConfig::discovery_unit`) will make this configurable.
- 32-bit platforms (`armv7`, `armhf`, `i386`) not supported — gluco-hub
  releases amd64/aarch64 manifests only today.
