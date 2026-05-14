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

### Known limitations

- Sensor unit is hard-coded to mg/dL upstream; mmol/L users see the
  reading under the `mmol` JSON attribute. A future upstream patch
  (`MqttSinkConfig::discovery_unit`) will make this configurable.
- 32-bit platforms (`armv7`, `armhf`, `i386`) not supported — gluco-hub
  releases amd64/aarch64 manifests only today.
