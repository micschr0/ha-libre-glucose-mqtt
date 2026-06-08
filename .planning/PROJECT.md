# Libre Glucose MQTT Bridge

## What This Is

A Home Assistant Supervisor app (formerly add-on) that polls glucose readings from LibreLink Up and publishes them to Home Assistant's MQTT broker with automatic sensor discovery. It wraps `gluco-hub-rs` — a Rust service purpose-built for this bridge — inside a thin Home Assistant container.

## Core Value

Reliably push LibreLink Up glucose data to Home Assistant via MQTT so users can monitor glucose levels in their HA dashboards, automations, and alerts.

## Requirements

### Validated

- ✓ **BRDG-01**: App runs as a Home Assistant Supervisor container (Docker-based) — v1.0
- ✓ **BRDG-02**: App polls LibreLink Up API for glucose readings — v1.0
- ✓ **BRDG-03**: App publishes readings to MQTT broker with HA discovery — v1.0
- ✓ **BRDG-04**: App supports amd64 and aarch64 architectures — v1.0
- ✓ **BRDG-05**: App has versioned configuration via config.yaml schema — v1.0
- ✓ **BRDG-06**: App has bilingual localisation (en, de) — v1.0
- ✓ **BRDG-07**: App has entrypoint script (run.sh) with init lifecycle — v1.0
- ✓ **BRDG-08**: App has AppArmor profile for security confinement — v1.0
- ✓ **BRDG-09**: App has icon and logo assets — v1.0
- ✓ **BRDG-10**: App passes unit test suite; integration test requires Docker — v1.0
- ✓ **BRDG-11**: Documentation accurate and current — v1.0
- ✓ **BRDG-12**: Release pipeline verified and CHANGELOG current — v1.0
- ✓ **BRDG-13**: GSD planning and state tracking established — v1.0
- ✓ **ENH-01**: Upstream multi-patient polling from a single LibreLink Up login — v1.1
- ✓ **ENH-02**: Per-patient MQTT entities with distinct unique_id/prefix/client_id — v1.1
- ✓ **ENH-03**: HA config schema for per-patient options — v1.1
- ✓ **ENH-04**: Per-patient token isolation — v1.1
- ✓ **ENH-05**: HTTP 429 rate-limit handling with Retry-After backoff — v1.1
- ✓ **ENH-06**: llu_version config option exposed — v1.1
- ✓ **ENH-07**: JSON schema hardening (critical fields made Option) — v1.1
- ✓ **ENH-08**: Schema fingerprint startup logging — v1.1
- ✓ **ENH-09**: Backward compatibility — v1.1
- ✓ **ENH-10**: MQTT discovery collision prevention — v1.1
### Active
None — v1.1 milestone complete.

### Out of Scope
- 32-bit platforms (armv7, armhf, i386) — upstream gluco-hub-rs lacks builds
- Real-time continuous glucose monitoring display — handled by HA dashboard, not the bridge
- Non-MQTT transport (HTTP API, WebSocket, etc.) — MQTT is the HA standard
- Multiple MQTT broker support — one broker per app instance

## Context
The project was built iteratively from the upstream `gluco-hub-rs` Rust service. v1.0 shipped core bridge functionality (13 requirements). v1.1 shipped the full enhancement set: HTTP 429 rate-limit handling, field-optionality hardening, llu_version config exposure, schema fingerprint startup logging, multi-source architecture for multi-account polling, per-patient MQTT entities with guaranteed unique discovery IDs — all 10 v1.1 requirements delivered.
## Constraints

- **Compatibility**: Must support Home Assistant Supervisor (not HA Container)
- **Architecture**: Only amd64 and aarch64 targets; upstream Rust crate lacks armv7
- **Dependency**: Requires Mosquitto broker app running in HA
- **Security**: AppArmor profile must not block required system calls
- **Legal**: Not affiliated with Abbott — must maintain clear disclaimer

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Wrap gluco-hub-rs container | Zero custom bridge code needed; upstream handles LibreLink Up protocol | ✓ Good |
| Use MQTT discovery | Home Assistant standard; automatic sensor creation | ✓ Good |
| Shell entrypoint (run.sh) | Minimal layer; Supervisor expects shell-based lifecycle | ✓ Good |
| Bilingual translations (en, de) | Project maintainer is German-speaking | ✓ Good |
| gluco-hub-rs multi-source (HashMap) | Single process handles N accounts — no per-instance overhead | ✓ Good |
| per_source MQTT tag | Per-account topic_prefix and client_id appended with source name | ✓ Good |
| llu_version nullable config | Empty uses upstream default; no migration needed for existing users | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-07 after v1.1 milestone*
