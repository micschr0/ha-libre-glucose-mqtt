# Plan: Phase 05 — API Resilience

**Phase:** 5 — API Resilience
**Goal:** Bridge withstands LibreLink Up API changes without data loss or operator emergency
**Requirements:** ENH-05, ENH-06, ENH-07, ENH-08, ENH-09

## Context

The add-on layer is thin (config.yaml + run.sh). Core resilience logic lives upstream in gluco-hub-rs. This phase delivers what the add-on can control: expose llu_version in config, add schema fingerprint startup logging, verify backward compatibility. Upstream items (429 handling, field Optionality, fingerprint generation) are tracked as dependencies.

## Tasks

### Task 5.1: Expose llu_version config option (ENH-06)

**Description:** Add `llu_version` to config.yaml schema and wire it through run.sh as `GLUCO_HUB__SOURCE__LLU__VERSION`. Upstream gluco-hub-rs already supports this env var — the add-on just doesn't expose it yet.

**Files:**
- `libre-glucose/config.yaml` — add schema entry + default
- `libre-glucose/run.sh` — export env var if set
- `libre-glucose/translations/en.yaml` — English label/description
- `libre-glucose/translations/de.yaml` — German label/description

**Type:** implementation

**Acceptance:**
- [ ] llu_version appears in HA add-on config UI
- [ ] run.sh exports GLUCO_HUB__SOURCE__LLU__VERSION when configured
- [ ] Field is nullable (empty = use upstream default)
- [ ] Both translations present

---

### Task 5.2: Schema fingerprint startup logging (ENH-08, add-on side)

**Description:** Log the expected LLU JSON field names at add-on startup so operators can detect API changes by comparing startup log fingerprints across versions.

**Files:**
- `libre-glucose/run.sh` — add fingerprint log block after env setup

**Type:** implementation

**Acceptance:**
- [ ] run.sh logs a sorted list of expected LLU JSON field names at startup
- [ ] Fingerprint includes: ValueInMgPerDl, ValueInMmolPerL, TrendArrow, Timestamp, PatientId
- [ ] Logged at info level, visible in HA Supervisor logs

---

### Task 5.3: Track upstream resilience dependencies (ENH-05, ENH-07, ENH-08)

**Description:** Document upstream gluco-hub-rs changes needed for full API resilience. Create a tracking issue/spec that the upstream maintainer can reference. These items live outside this repo.

**Files:**
- `.planning/phases/05-api-resilience/05-UPSTREAM-TRACKING.md`

**Required upstream changes:**
- ENH-05: HTTP 429 rate-limit handling with Retry-After header backoff
- ENH-07: Make critical wire fields Option (ValueInMgPerDl, TrendArrow, Timestamp) so field renames don't crash
- ENH-08: Generate schema fingerprint hash of expected field names at startup (Rust side)

**Type:** documentation

**Acceptance:**
- [ ] Upstream tracking doc written with specific code pointers and expected behavior
- [ ] Each item has clear acceptance criteria for upstream implementation

---

### Task 5.4: Backward compatibility verification (ENH-09)

**Description:** Verify that existing v1.0 single-patient configurations continue working identically with the new llu_version option unset.

**Files:**
- `tests/test-run-sh.sh` — add test case for llu_version unset
- `libre-glucose/run.sh` — verify no behavior change when llu_version is empty

**Type:** verification

**Acceptance:**
- [ ] Test confirms no GLUCO_HUB__SOURCE__LLU__VERSION exported when llu_version unset
- [ ] Existing env var tests still pass (no regression)
- [ ] run.sh exits 0 with empty llu_version (no parse error)

---

### Task 5.5: Verification and Summary

**Description:** Write SUMMARY.md and VERIFICATION.md. Update STATE.md.

**Files:**
- `.planning/phases/05-api-resilience/05-SUMMARY.md`
- `.planning/phases/05-api-resilience/05-VERIFICATION.md`

**Type:** verification

**Acceptance:**
- [ ] All prior tasks completed
- [ ] SUMMARY.md written
- [ ] VERIFICATION.md written with status
- [ ] STATE.md updated
