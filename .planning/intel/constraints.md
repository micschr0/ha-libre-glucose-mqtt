# Constraints

**Source type:** All 5 classified documents are DOC (documentation), not SPECs.  
**No formal SPECs found.** The following technical constraints are extracted from documentation.

---

## Architecture Constraints

| Constraint | Type | Source | Detail |
|------------|------|--------|--------|
| Must run on HA Supervisor (not HA Container) | nfr | `README.md` (root) | Supervisor-only; HA Container installations cannot run apps |
| Requires Mosquitto broker app + MQTT HA integration | nfr | `libre-glucose/DOCS.md`, `README.md` (root) | App refuses to start without MQTT service |
| Only amd64 and aarch64 targets | nfr | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md`, `README.md` (root) | Upstream gluco-hub-rs lacks armv7/armhf/i386 builds |
| AppArmor must grant `r` permission for s6-overlay v3 shebangs | nfr | `libre-glucose/CHANGELOG.md` (2026.516.1) | Shebang scripts require read during execve; `ix` alone causes EACCES |
| client_id constrained to 1–23 alphanumeric/-/_ chars | nfr | `libre-glucose/DOCS.md` | MQTT client id constraint; also used in HA discovery unique-id |
| poll_interval_secs constrained to 30–600 | nfr | `libre-glucose/DOCS.md` | Hard floor (60s LibreLink Up update rate) and ceiling |

## Data Constraints

| Constraint | Type | Source | Detail |
|------------|------|--------|--------|
| DLQ capacity: up to 10,000 readings (~35 days at 5-min raster) | nfr | `libre-glucose/DOCS.md` | Persistent at /data/state |
| Clock View Cache-Control: no-store (PHI content) | protocol | `libre-glucose/DOCS.md` | Prevents caching of glucose readings |
| MQTT wire payload always includes both mgdl + mmol fields | api-contract | `libre-glucose/CHANGELOG.md` | glucose_unit option only changes discovery unit, not wire format |
| Sensor unit hard-coded to mg/dL upstream (discovery_unit configurable at app level) | api-contract | `libre-glucose/DOCS.md` | Upstream limitation; workaround via glucose_unit config option |

## Security Constraints

| Constraint | Type | Source | Detail |
|------------|------|--------|--------|
| llu_password must never be written to MQTT or logs | nfr | `libre-glucose/DOCS.md` | Stored only in HA Supervisor options DB |
| Security reports go through GitHub PVR only (no email fallback) | protocol | `SECURITY.md`, `libre-glucose/CHANGELOG.md` | (2026.516.1) Changed from previous email+PVR setup |
| Only latest published app release receives security fixes | nfr | `SECURITY.md` | App version mirrors upstream CalVer |
| security@ alias removed in favor of PVR | protocol | `libre-glucose/CHANGELOG.md` (2026.516.1) | Both repository.yaml and SECURITY.md updated |
| Disclaimer required: not affiliated with Abbott, not a medical device, use at own risk | legal | All 5 docs | Broadened in 2026.516.0 to explicitly list three risks |
| AGPL-3.0-or-later licence (consistent with upstream) | legal | `README.md` (root), `libre-glucose/README.md` | |

## Release Constraints

| Constraint | Type | Source | Detail |
|------------|------|--------|--------|
| Three files must carry same upstream tag: Dockerfile, build.yaml, config.yaml | protocol | `libre-glucose/DOCS.md` | Enforced by CI version-consistency job |
| Renovate group `gluco-hub-upstream` bumps all three atomically | protocol | `libre-glucose/DOCS.md` | Human must add CHANGELOG narrative |
| HASSIO_TOKEN assigned by Supervisor, sourced internally | protocol | `libre-glucose/DOCS.md` (via run.sh) | Not user-configurable |

## Status

**0 blockers.** All constraints extracted from DOC sources. No SPEC-type documents exist, so no SPEC-vs-ADR contradictions apply.
