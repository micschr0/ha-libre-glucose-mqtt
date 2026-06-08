---
status: passed
phase: 5
name: API Resilience
verified: 2026-06-07
---

# Phase 5 Verification: API Resilience

## Success Criteria

### ✅ 1. llu_version exposed in add-on config UI
- config.yaml: `llu_version: ""` default, `str?` schema
- run.sh: `bashio::config 'llu_version'` → `GLUCO_HUB__SOURCE__LLU__VERSION` export
- Bilingual translations present (en/de)
- Field is nullable — empty uses upstream default

### ✅ 2. Schema fingerprint logged at startup
- run.sh logs: `LLU schema fingerprint: ValueInMgPerDl, ValueInMmolPerL, TrendArrow, Timestamp, PatientId`
- Logged at info level, visible in HA Supervisor logs

### ✅ 3. Backward compatibility preserved
- Test confirms `GLUCO_HUB__SOURCE__LLU__VERSION` NOT exported when `llu_version` empty
- All existing 19 env var assertions still pass
- No regression in existing behavior

### ⏭ 4. HTTP 429 handling (ENH-05)
- Depends on upstream gluco-hub-rs change
- Tracked in 05-UPSTREAM-TRACKING.md

### ⏭ 5. Field Optionality (ENH-07)
- Depends on upstream gluco-hub-rs change
- Tracked in 05-UPSTREAM-TRACKING.md

## Summary

| Criterion | Status |
|-----------|--------|
| llu_version config | ✅ PASS |
| Schema fingerprint log | ✅ PASS |
| Backward compat | ✅ PASS |
| HTTP 429 handling | ⏭ Upstream |
| Field Optionality | ⏭ Upstream |

**Overall: PASSED** — All add-on-layer deliverables complete. Two upstream dependencies tracked for gluco-hub-rs coordination. Phase 5 shippable independently of Phase 6.
