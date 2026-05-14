# Changelog

All notable changes to this add-on are documented here. Versioning
follows the upstream [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs)
CalVer scheme (`YYYY.0M0D.PATCH`) so the add-on version always names the
gluco-hub release it bundles.

## [Unreleased]

### Added

- Initial release: thin wrapper around `ghcr.io/micschr0/gluco-hub`,
  shipping a Dockerfile that lays the upstream binary onto a HA Debian
  base image, plus a `bashio` entrypoint that maps add-on options and
  the Mosquitto MQTT service info into `GLUCO_HUB__*` environment
  variables.
- Supported platforms: `amd64`, `aarch64`.
- MQTT auto-discovery enabled by default — sensor entity appears under
  the **Glucose Hub** device within ~10 seconds of starting.
- Persistent DLQ at `/data/state` survives add-on restarts and updates.
- Custom AppArmor profile (`apparmor.txt`) confines the add-on to
  outbound HTTPS + MQTT and `/data` writes; capabilities are dropped to
  the minimum needed. Earns +1 on the Supervisor security rating
  (target rating: 6/6).
- HA UI assets: `icon.png` (128×128), `logo.png` (250×100),
  English + German translation files for all options.
- Liveness probe via Supervisor watchdog
  (`tcp://[HOST]:[PORT:8080]`) — the add-on auto-restarts on socket
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
