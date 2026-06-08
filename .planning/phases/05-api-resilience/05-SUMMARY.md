---
status: complete
phase: 5
name: API Resilience
completed: 2026-06-07
---

# Phase 5 Summary: API Resilience

## Accomplishments

1. **llu_version config exposed (ENH-06)** — New nullable config option in config.yaml. run.sh exports `GLUCO_HUB__SOURCE__LLU__VERSION` when set. Bilingual labels (en/de).

2. **Schema fingerprint logging (ENH-08, add-on side)** — run.sh logs sorted LLU JSON field names at startup so operators can detect API changes by comparing fingerprints across versions.

3. **Backward compatibility verified (ENH-09)** — Test confirms `GLUCO_HUB__SOURCE__LLU__VERSION` is NOT exported when `llu_version` is unset. All existing env var tests pass (19 checked).

4. **Upstream tracking doc written** — Three upstream gluco-hub-rs changes documented with code pointers and acceptance criteria (429 handling, field Optionality, Rust-side fingerprint).

## Files Changed

| File | Change |
|------|--------|
| `libre-glucose/config.yaml` | +llu_version option (default + schema) |
| `libre-glucose/run.sh` | +llu_version config read + export + schema fingerprint log |
| `libre-glucose/translations/en.yaml` | +llu_version label/description |
| `libre-glucose/translations/de.yaml` | +llu_version label/description |
| `tests/mock-bashio.sh` | +llu_version mock config |
| `tests/test-run-sh.sh` | +llu_version backward compat assertion |

## Requirements Status

| Req | Description | Status |
|-----|-------------|--------|
| ENH-05 | HTTP 429 handling | Pending upstream |
| ENH-06 | llu_version exposed | ✅ Done |
| ENH-07 | Field Optionality | Pending upstream |
| ENH-08 | Schema fingerprint | ✅ Add-on side done; upstream pending |
| ENH-09 | Backward compat | ✅ Verified |

## Notes
- ENH-05, ENH-07, ENH-08 (Rust side) depend on upstream gluco-hub-rs changes — tracked in 05-UPSTREAM-TRACKING.md
- Drift-check passes (2026.516.2 across all three refs)
- Unit tests pass (19 env var assertions)
