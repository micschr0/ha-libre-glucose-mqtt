# Plan: Phase 06 — Multi-Patient Support

**Phase:** 6 — Multi-Patient Support
**Goal:** One add-on instance monitors multiple LLU accounts/patients with per-patient MQTT entities
**Requirements:** ENH-01, ENH-02, ENH-03, ENH-04, ENH-10
**Status:** BLOCKED — depends on upstream gluco-hub-rs multi-source architecture

## Blocker

Upstream gluco-hub-rs currently supports exactly one LibreLink Up account per binary (`Option<LluSourceConfig>` in config.rs). Multi-source support (`HashMap<String, LluSourceConfig>`) needs to be implemented upstream before add-on-layer work can begin.

## Tasks (preparation only)

### Task 6.1: Upstream multi-source spec (ENH-01)

**Description:** Write detailed upstream change spec for gluco-hub-rs multi-source architecture. Documents the HashMap-based config, per-source polling, per-source token caches, and per-source sink routing.

**Type:** documentation
**Status:** Pending upstream

### Task 6.2: config.yaml multi-account schema (ENH-03)

**Description:** Design the HA config schema for multiple accounts. Options: fixed list with sub-dicts, or auto-discovery via `_patients` MQTT topic. Must maintain backward compatibility with single-account configs.

**Type:** implementation (add-on)
**Status:** Pending upstream

### Task 6.3: run.sh TOML generation (ENH-01)

**Description:** Generate TOML config from list schema for upstream multi-source consumption. Handles the config migration from flat single-account to named multi-account.

**Type:** implementation (add-on)
**Status:** Pending upstream

### Task 6.4: Per-patient MQTT entities (ENH-02, ENH-10)

**Description:** Ensure MQTT topic naming and discovery unique_id are per-patient. Verify no collision between patients.

**Type:** implementation (add-on + upstream)
**Status:** Pending upstream

### Task 6.5: Token isolation verification (ENH-04)

**Description:** Verify per-patient token caches are isolated. One patient's auth failure must not invalidate other patients' sessions.

**Type:** verification
**Status:** Pending upstream

### Task 6.6: Backward compatibility re-verification (ENH-09)

**Description:** Verify single-account v1.0 configs still work with multi-account schema present.

**Type:** verification
**Status:** Pending upstream

## Next Steps

1. Coordinate with upstream gluco-hub-rs maintainer on multi-source architecture
2. Implement HashMap<String, LluSourceConfig> in gluco-hub-rs
3. Per-source token caches and polling
4. Then: implement add-on layer changes (config schema, TOML generation, per-patient topics)
