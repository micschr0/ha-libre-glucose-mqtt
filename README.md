<!-- authoring-audit: 2026-07-16 BLUF,ModePurity,ConceptBudget,Examples,Terminology -->

# ha-libre-glucose-mqtt — Home Assistant app repository

> ⚠️ **Not affiliated with Abbott Laboratories.** Unofficial research and self-hosting tool. Use may violate Abbott's LibreLink Up Terms of Service. No warranty. Not for medical decisions, therapy, dosing, or diagnosis.

This repository ships a single Home Assistant Supervisor app: **Libre Glucose MQTT Bridge** — a thin Bash wrapper around [`gluco-hub-rs`](https://github.com/micschr0/gluco-hub-rs) that polls LibreLink Up glucose readings and publishes them to your MQTT broker with automatic sensor discovery.

## Install

1. In Home Assistant, open **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top right) → **Repositories**.
3. Add:
   ```
   https://github.com/micschr0/ha-libre-glucose-mqtt
   ```
4. Refresh the store; **Libre Glucose MQTT Bridge** appears in a new section.
5. Click it → **Install**. Configure, then **Start**.

## Requirements

- Home Assistant OS or Supervised (Supervisor required — Container installations cannot run apps).
- The official **Mosquitto broker** app with the MQTT integration configured.
- A LibreLink Up account with at least one active connection.

## Architecture

```text
LibreLink Up  ──►  Libre Glucose MQTT Bridge  ──►  Mosquitto  ──►  HA entities
                   (runs gluco-hub-rs)
```

`run.sh` reads `/data/options.json` via bashio, queries the Mosquitto credentials from the HA MQTT service, exports `GLUCO_HUB__*` environment variables, and execs the upstream binary. No polling or MQTT logic lives in this repository.

## Supported platforms

`amd64`, `aarch64`. RPi 3 in 64-bit mode works. 32-bit ARM (`armv7`, `armhf`, `i386`) is not supported — follow [gluco-hub-rs](https://github.com/micschr0/gluco-hub-rs) for status.

## Maintenance — upgrading to a new gluco-hub release

Three files carry the upstream tag and must stay in sync:

- `libre-glucose/Dockerfile` — `ARG GLUCO_HUB_TAG=...`
- `libre-glucose/build.yaml` — `args.GLUCO_HUB_TAG: "..."`
- `libre-glucose/config.yaml` — `version: "..."` (mirrors the upstream tag exactly)

**Automated:** Renovate watches `ghcr.io/micschr0/gluco-hub` and opens one PR (group `gluco-hub-upstream`) bumping all three atomically. The CI `version-consistency` job rejects any commit where they diverge. Renovate runs on a `"before 6am on monday"` schedule; requires the `RENOVATE_TOKEN` repo secret (fine-grained PAT: Contents / PRs / Workflows / Issues RW, Metadata RO).

**Manual:** Review the Renovate PR, add a `Changed` or `Added` entry under `## [Unreleased]` in `CHANGELOG.md` describing user-visible changes, and merge to `main`.

**New upstream config fields:** exposing them in the HA UI is a deliberate decision — not every field belongs in the options panel. When wiring one up, touch `config.yaml` (option + schema), `run.sh` (export), both `translations/*.yaml`, and `tests/`.

## Releasing

The app uses CalVer: `YYYY.MMDD.PATCH` (e.g. `2026.515.0`). Tags are prefixed `v`.

```bash
task release           # cut today's CalVer (commit + tag + push)
task release:patch     # same-day hotfix
task release:rc        # pre-release (-rc.N suffix)
task release:dry       # preview without changes
```

Pushing a `v*` tag triggers `release.yml`, which builds for `linux/amd64` + `linux/arm64`, signs with cosign (keyless), attaches a SLSA provenance attestation, and publishes to `ghcr.io/micschr0/libre-glucose`:

| Trigger | Tags published |
|---|---|
| `push: main` | `:main`, `:sha-<short>` |
| pre-release tag `vX.Y.Z-rc.N` | `:X.Y.Z-rc.N`, `:testing`, `:sha-<short>` |
| final tag `vX.Y.Z` | `:X.Y.Z`, `:latest`, `:stable`, `:sha-<short>` |
| pull_request | build-only, no push |

HA Supervisor pulls the image tag matching `config.yaml`'s `version:` field.

## Reporting issues

- App-specific (manifest, install, run.sh): [ha-libre-glucose-mqtt issues](https://github.com/micschr0/ha-libre-glucose-mqtt/issues)
- Polling / MQTT / LibreLink Up logic: [gluco-hub-rs issues](https://github.com/micschr0/gluco-hub-rs/issues)

## Trademarks

LibreLink, LibreView, FreeStyle Libre, Libre 2, and Libre 3 are trademarks of Abbott. This project is not affiliated with Abbott Laboratories.

## Licence

AGPL-3.0-or-later — see `LICENSE`. Consistent with the upstream `gluco-hub-rs` licence.
