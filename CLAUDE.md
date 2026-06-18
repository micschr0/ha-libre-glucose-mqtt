# ha-libre-glucose-mqtt

Home Assistant add-on bridge wrapping gluco-hub-rs. Shell scripts + Docker, no Rust.

## Version alignment

- `config.yaml version:` → HA Supervisor pull tag (`ghcr.io/.../libre-glucose:<version>`). Must match an existing GHCR image.
- `build.yaml GLUCO_HUB_TAG` → upstream gluco-hub-rs image tag (Renovate-managed).
- `config.yaml`, `build.yaml`, `Dockerfile ARG` — all three must align after manual bump. CI drift-check catches 2 of 3.
- `GLUCO_HUB_TAG` also appears in `ci.yml` (×3, CI build-args) — Renovate-managed via a customManager, NOT covered by the drift-check.

## Testing

- `tests/test-run-sh.sh` — single-account env assertions (19 vars).
- `tests/test-run-sh-multi.sh` — multi-account TOML generation assertions (per-source sections, MQTT creds, `per_source=true`).
- `tests/test-check-config.sh` — feeds env into `gluco-hub check-config` via Docker.
- `tests/mock-bashio.sh` — mocks all `bashio::config` keys and `bashio::services` calls.

## Bash gotchas

- `bashio::services` vars: `MQTT_USERNAME` / `MQTT_PASSWORD` (not `MQTT_USER` / `MQTT_PW`)
- Undefined vars in heredocs (`<<TOML`) are **not** caught by `set -u` — silently expand to empty
- Multi-account `llu_accounts` array → TOML via `printf` + heredoc, one section per entry
- Multi-account TOML is validated via `gluco-hub check-config` before `exec` (run.sh pre-flight); single-account uses ENV, no TOML.

## Release

- CalVer: `YYYY.0M0D.PATCH` (e.g. 2026.607.0). Tag as `vYYYY.0M0D.PATCH`.
- CHANGELOG.md section header must match tag version or GitHub Release step fails
- `git reset HEAD .claude/ .planning/` before release commits (infrastructure is not source code)
- Release image tags: `:2026.607.0`, `:latest`, `:stable`, `:sha-<short>`
