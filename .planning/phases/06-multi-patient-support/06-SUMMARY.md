---
status: complete
phase: 6
name: Multi-Patient Support
completed: 2026-06-07
---

# Phase 6 Summary: Multi-Patient Support

## Status: COMPLETE

All upstream (gluco-hub-rs) and add-on layer changes implemented.

### Upstream gluco-hub-rs (2026.606.0)
- Multi-source architecture: `HashMap<String, LluSourceConfig>` in config
- Per-source poll tasks with independent error isolation
- Per-source MQTT sinks with `per_source: true` for per-account topics
- HTTP 429 rate-limit handling with Retry-After backoff
- Field Optionality (timestamp, value_in_mg_per_dl → Option)
- Schema fingerprint startup log
- 141 tests pass

### Add-on Layer
- `config.yaml`: `llu_accounts` list schema with name, email, password, region, patient_id, timezone, version
- `run.sh`: Multi-account detection → TOML config generation with `per_source=true`
- Backward compat: single-account env var flow unchanged
- Drift check passes (2026.606.0)

## Files Changed

| Repo | File | Change |
|------|------|--------|
| gluco-hub-rs | config.rs | +sources HashMap, +per_source bool |
| gluco-hub-rs | main.rs | Multi-source build, per-source poll/sinks |
| gluco-hub-rs | auth.rs | +send_with_retry (429 handling) |
| gluco-hub-rs | wire.rs | Field Optionality |
| gluco-hub-rs | mapping.rs | Graceful None handling |
| gluco-hub-rs | source.rs | filter_map instead of collect::Result |
| ha-libre-glucose-mqtt | config.yaml | +llu_accounts list schema |
| ha-libre-glucose-mqtt | run.sh | +TOML generation for multi-account |
| ha-libre-glucose-mqtt | Dockerfile/build.yaml/config.yaml | Tag 2026.606.0 |

## Requirements Status

| Req | Description | Status |
|-----|-------------|--------|
| ENH-01 | Multi-patient polling | ✅ Upstream multi-source |
| ENH-02 | Per-patient MQTT entities | ✅ per_source=true |
| ENH-03 | HA config schema for per-patient | ✅ llu_accounts list |
| ENH-04 | Per-account token isolation | ✅ Per-source tasks |
| ENH-05 | HTTP 429 handling | ✅ 3-retry with Retry-After |
| ENH-06 | llu_version exposed | ✅ Phase 5 shipped |
| ENH-07 | Field Optionality | ✅ Option<T> fields |
| ENH-08 | Schema fingerprint | ✅ Startup log |
| ENH-09 | Backward compat | ✅ Single-account preserved |
| ENH-10 | MQTT collision prevention | ✅ Per-source unique topics |
