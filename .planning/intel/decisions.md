# Decisions

**Source type:** All 5 classified documents are DOC (documentation), not ADRs.  
**No formal ADRs found.** No locked decisions exist in any ingested document.

The following architectural decisions are documented in the source docs but originate from DOC-level narrative rather than dedicated decision records. They are surfaced here for downstream synthesis.

---

## Architecture & Deployment

| Decision | Source | Status |
|----------|--------|--------|
| Wrap gluco-hub-rs container image — no custom bridge code | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed (v1.0) |
| Pre-built multi-arch GHCR image replaces local Dockerfile build at install time | `libre-glucose/CHANGELOG.md` (2026.516.0) | Deployed |
| Local Dockerfile + build.yaml kept as build-from-source fallback | `libre-glucose/CHANGELOG.md` | Deployed |
| Shell entrypoint (run.sh) using bashio for config mapping | `libre-glucose/DOCS.md`, `libre-glucose/run.sh` | Deployed |
| HA MQTT auto-discovery for sensor creation | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| Persistent DLQ at /data/state (up to 10k readings) | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| AppArmor profile for security confinement | `libre-glucose/CHANGELOG.md` | Deployed |
| Slug flattened: ha-libre-glucose-mqtt → libre-glucose | `libre-glucose/CHANGELOG.md` | Deployed |

## Versioning & Releases

| Decision | Source | Status |
|----------|--------|--------|
| CalVer scheme YYYY.MMDD.PATCH (same as upstream gluco-hub-rs) | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| App version mirrors bundled upstream CalVer tag exactly | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| Renovate tracks upstream ghcr.io/micschr0/gluco-hub tag | `libre-glucose/DOCS.md` | Deployed |
| Taskfile.yml manages local release workflow | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| Multi-channel GHCR image tags (main, develop, testing, stable) | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| cosign keyless signing + SLSA attestation on release | `libre-glucose/CHANGELOG.md` | Deployed |

## Configuration & UI

| Decision | Source | Status |
|----------|--------|--------|
| LibreLink Up options exposed via config.yaml schema | `libre-glucose/DOCS.md` | Deployed |
| Default client_id shortened from gluco-hub-ha to ha | `libre-glucose/CHANGELOG.md` (2026.516.1) | Deployed |
| glucose_unit option (mgdl/mmol) surfaced in config | `libre-glucose/CHANGELOG.md` (2026.516.0) | Deployed |
| Bilingual translations (en, de) | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Deployed |
| Clock View HTML page served at Ingress path /clock | `libre-glucose/DOCS.md` | Deployed |
| Trend sensor as separate HA entity (device_class: enum) | `libre-glucose/CHANGELOG.md` (2026.516.2) | Deployed |
| MQTT health/stats/patients topics published alongside glucose topic | `libre-glucose/DOCS.md` | Deployed |

## CI & Security

| Decision | Source | Status |
|----------|--------|--------|
| frenck/action-addon-linter + yamllint + hadolint + shellcheck on every PR | `libre-glucose/CHANGELOG.md` | Deployed |
| Security reporting via GitHub Private Vulnerability Reporting only | `libre-glucose/CHANGELOG.md` (2026.516.1), `SECURITY.md` | Deployed |
| GitHub Pages with Cayman theme for static site | `libre-glucose/CHANGELOG.md` | Deployed |

## Status

Zero formal ADRs exist. All 5 ingested documents are DOC type.  
**No locked decisions present.**
