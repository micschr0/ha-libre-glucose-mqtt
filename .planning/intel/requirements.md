# Requirements

**Source type:** All 5 classified documents are DOC (documentation), not PRDs.  
**No formal PRDs found.** The following requirements are extracted from documentation and changelog entries.

Existing requirements in `.planning/REQUIREMENTS.md` track 13 BRDG requirements (BRDG-01–13) and 4 ENHN enhancement requests. All v1.0 BRDG requirements are marked complete except BRDG-10, BRDG-11, BRDG-12, BRDG-13. The ingested docs confirm the shipped-state of all completed requirements.

---

## Extracted Capabilities (from DOCS.md, CHANGELOG.md)

| Capability | Source | Notes |
|------------|--------|-------|
| Poll LibreLink Up at configurable interval (30–600s, default 60s) | `libre-glucose/DOCS.md` | Maps to BRDG-02 ✓ |
| Publish glucose reading + attributes to MQTT | `libre-glucose/DOCS.md` | Maps to BRDG-03 ✓ |
| HA MQTT auto-discovery for glucose sensor entity | `libre-glucose/DOCS.md` | Maps to BRDG-03 ✓ |
| HA MQTT auto-discovery for trend sensor entity (sibling entity, device_class: enum) | `libre-glucose/CHANGELOG.md` (2026.516.2) | New since v1.0 |
| Publish _health, _stats, _patients MQTT topics | `libre-glucose/DOCS.md` | Operational |
| State persistence/DLQ at /data/state (up to 10k readings) | `libre-glucose/DOCS.md` | Maps to BRDG-01 ✓ |
| Clock View web UI at Ingress path /clock with responsive classes | `libre-glucose/DOCS.md` | Already deployed |
| Configurable glucose unit (mgdl or mmol) | `libre-glucose/CHANGELOG.md` (2026.516.0) | Maps to BRDG-02 ✓ |
| Bilingual translations (en, de) for config options | `libre-glucose/DOCS.md` | Maps to BRDG-06 ✓ |
| AppArmor confinement profile | `libre-glucose/CHANGELOG.md` | Maps to BRDG-08 ✓ |
| Multi-arch image (amd64 + aarch64) from GHCR | `libre-glucose/CHANGELOG.md` | Maps to BRDG-04 ✓ |
| CalVer release scheme with automated CI/CD | `libre-glucose/DOCS.md`, `libre-glucose/CHANGELOG.md` | Maps to BRDG-12 |
| CI linting: yamllint, hadolint, shellcheck, addon-linter per PR | `libre-glucose/CHANGELOG.md` | Maps to BRDG-10 |
| Config options exposed through HA UI via config.yaml schema | `libre-glucose/DOCS.md` | Maps to BRDG-05 ✓ |
| E-Ink display mode (?eink=1 on /clock) | `libre-glucose/DOCS.md` | Already deployed |

## Integration with Existing Requirements

No contradictions with `.planning/REQUIREMENTS.md`:

- Existing v1.0 requirements (BRDG-01–09, BRDG-13) are confirmed complete by ingested docs.
- ENHN-01 (multi-account), ENHN-02 (configurable polling — already delivered), ENHN-03 (health endpoint — _health topic delivered), ENHN-04 (API changes — no doc changes detected).
- **Note:** ENHN-02 and ENHN-03 appear partially delivered per DOCS.md — polling interval is configurable (30–600s), and `_health` MQTT topic exists. Existing requirements.md may need updating.

## Deficit vs Existing Requirements

| Requirement | Status in Docs | Notes |
|-------------|----------------|-------|
| BRDG-10 (test suite) | Not documented in any ingested doc | Tests exist at `tests/` but not described in DOCS/CHANGELOG |
| BRDG-11 (documentation) | Confirmed present | DOCS.md, README.md, CHANGELOG.md all current |
| BRDG-12 (release pipeline) | Documented | CalVer + Taskfile + release.yml in CHANGELOG and DOCS |
| BRDG-13 (GSD tracking) | Not documented in ingested docs | Exists as `.planning/` files but not referenced |

## Status

**0 blockers.** No PRD-vs-PRD contradictions since no PRD documents exist.  
All requirements extracted are consistent with existing `.planning/REQUIREMENTS.md`.
