# Requirements: Libre Glucose MQTT Bridge

**Defined:** 2026-06-07
**Core Value:** Reliably push LibreLink Up glucose data to Home Assistant via MQTT so users can monitor glucose levels in their HA dashboards, automations, and alerts.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Bridge Core

- [x] **BRDG-01**: App runs as a Home Assistant Supervisor container (Docker-based)
- [x] **BRDG-02**: App polls LibreLink Up API for glucose readings
- [x] **BRDG-03**: App publishes readings to MQTT broker with HA discovery
- [x] **BRDG-04**: App supports amd64 and aarch64 architectures
- [x] **BRDG-05**: App has versioned configuration via config.yaml schema

### Quality & Testing

- [x] **BRDG-06**: App has bilingual localisation (en, de)
- [x] **BRDG-07**: App has entrypoint script (run.sh) with init lifecycle
- [x] **BRDG-08**: App has AppArmor profile for security confinement
- [x] **BRDG-09**: App has icon and logo assets

### Verification

- [x] **BRDG-10**: App passes unit and integration test suite
- [x] **BRDG-11**: App is documented for end-user installation and configuration
- [x] **BRDG-12**: App version is tagged and released via automated pipeline
- [x] **BRDG-13**: GSD planning and state tracking established for ongoing development

## v1.1 Requirements

### Multi-Patient Support (ENHN-01)

- [ ] **ENH-01**: Upstream gluco-hub-rs supports multi-patient polling from a single LibreLink Up login
- [ ] **ENH-02**: Per-patient MQTT sensor entities with distinct unique_id, topic_prefix, and client_id
- [ ] **ENH-03**: HA config schema updated for per-patient options (list or auto-discovery)
- [ ] **ENH-04**: Per-patient token isolation — separate token cache per patient

### API Resilience (ENHN-04)

- [ ] **ENH-05**: Upstream gluco-hub-rs handles HTTP 429 rate-limit with Retry-After backoff
- [ ] **ENH-06**: API version header (llu_version) exposed in add-on config
- [ ] **ENH-07**: JSON schema hardening — critical fields made Option with graceful defaulting
- [ ] **ENH-08**: Schema fingerprint logging for detecting LibreLink Up API changes

### Cross-cutting

- [ ] **ENH-09**: Backward compatibility — existing single-patient configs keep working
- [ ] **ENH-10**: MQTT discovery collision prevention — guaranteed unique unique_id per patient

## v2 Requirements

Deferred to future release.

Nothing currently deferred — all enhancement requests promoted to v1.1.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| 32-bit platform support | Upstream gluco-hub-rs lacks armv7/i386 builds |
| Real-time CGM display | Handled by HA dashboard/Grafana, not bridge |
| Non-MQTT transport | MQTT is the HA standard for sensor data |
| Multiple broker support | One broker instance per app instance |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BRDG-01 | 1 | Complete |
| BRDG-02 | 1 | Complete |
| BRDG-03 | 1 | Complete |
| BRDG-04 | 1 | Complete |
| BRDG-05 | 1 | Complete |
| BRDG-06 | 1 | Complete |
| BRDG-07 | 1 | Complete |
| BRDG-08 | 1 | Complete |
| BRDG-09 | 1 | Complete |
| BRDG-10 | 1 | Complete |
| BRDG-11 | 1 | Complete |
| BRDG-12 | 1 | Complete |
| BRDG-13 | 1 | Complete |
| ENH-01 | 6 | Pending |
| ENH-02 | 6 | Pending |
| ENH-03 | 6 | Pending |
| ENH-04 | 6 | Pending |
| ENH-05 | 5 | Pending |
| ENH-06 | 5 | Pending |
| ENH-07 | 5 | Pending |
| ENH-08 | 5 | Pending |
| ENH-09 | 5 | Pending |
| ENH-10 | 6 | Pending |

**Coverage:**
- v1 requirements: 13/13 complete
- v1.1 requirements: 10 pending, 10/10 mapped
- Unmapped: 0

---
*Requirements defined: 2026-06-07*
*Last updated: 2026-06-07 — v1.1 roadmap created; requirements mapped to phases 5-6*
