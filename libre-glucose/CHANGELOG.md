# Changelog

All notable changes to this app are documented here. Versioning follows
the upstream [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs)
CalVer scheme (`YYYY.0M0D.PATCH`) so the app version always names the
gluco-hub release it bundles.

## [Unreleased]

### Changed

- **Disclaimer wording (II)**: short callouts in both READMEs now
  open with the not-affiliated-with-Abbott clause as a bold first
  sentence, dropped the trailing `See DOCS.md → Disclaimer for full
  details` pointer (the callout is already self-contained), and the
  full long-form text in `DOCS.md` stays for readers who want it.
- **GitHub Pages**: new `_config.yml` enables Jekyll with the Cayman
  theme so the existing Markdown files render as a minimal static
  site at <https://micschr0.github.io/ha-libre-glucose-mqtt/>.
  Landing page is `README.md`; no separate build pipeline needed.
- **Disclaimer wording** across `README.md`, `libre-glucose/README.md`,
  `libre-glucose/DOCS.md`, and `SECURITY.md` now spells out three
  previously-implicit risks: (a) this app is unofficial and not
  affiliated with Abbott, (b) use may violate Abbott's LibreLink Up
  Terms of Service and the maintainers accept no liability for
  account suspension, (c) the software is provided "as is" — use at
  your own risk. The medical-device wording is retained and slightly
  broadened ("medical decisions" alongside "therapy, dosing,
  diagnosis").

### Added

- **Pre-built multi-arch GHCR image** — `.github/workflows/release.yml`
  now builds the addon for `linux/amd64` + `linux/arm64` natively
  (no QEMU), signs the manifest list with cosign (keyless OIDC),
  attaches a SLSA build-provenance attestation, and publishes to
  `ghcr.io/micschr0/libre-glucose`. Tag channels mirror upstream
  gluco-hub-rs: `:main`, `:develop`, `:testing` (pre-release), and on
  final tags `:X.Y.Z`, `:X.Y`, `:X`, `:latest`, `:stable`,
  `:sha-<short>`. HA Supervisor now pulls the pre-built image at
  install time instead of building locally — ~30 s vs ~60 s
  first-install, deterministic across users, verifiable provenance.
- **`config.yaml` `image:` field** points HA Supervisor at the new
  GHCR-published manifest. The local `Dockerfile` + `build.yaml` stay
  as a build-from-source fallback.
- **`Taskfile.yml` + `scripts/release.sh`** — same CalVer cadence as
  upstream gluco-hub-rs (`YYYY.MMDD.PATCH`, MMDD = month*100 + day).
  Tasks: `release`, `release:patch`, `release:rc`, `release:dry`.

### Changed

- **Upstream pin**: `gluco-hub` image tag bumped from rolling `:develop`
  to the first stable release `2026.515.0`. The app's own `version:`
  now mirrors the upstream CalVer exactly (was `0.2.0-dev`), so a
  running app version names the bundled binary release at a glance.

### Added

- **`glucose_unit` option** (`mgdl` | `mmol`, default `mgdl`) — surfaces
  the upstream `MqttSinkConfig::discovery_unit` field added in
  gluco-hub-rs PR #17. Pick `mmol` for EU/UK readouts; the HA discovery
  sensor entity then reports `mmol/L` directly instead of the
  US-default `mg/dL`. The MQTT JSON wire payload is unchanged — both
  `mgdl` and `mmol` fields are always emitted, so other subscribers
  see the same JSON they did before. Pinned to the upstream `:develop`
  channel until gluco-hub-rs cuts its first CalVer release; Renovate
  will switch us to a stable tag once one exists.

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
