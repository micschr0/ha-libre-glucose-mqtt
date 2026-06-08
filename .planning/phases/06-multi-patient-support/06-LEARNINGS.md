---
phase: 6
phase_name: "Multi-Patient Support"
project: "Libre Glucose MQTT Bridge"
generated: "2026-06-07"
counts:
  decisions: 7
  lessons: 5
  patterns: 4
  surprises: 6
missing_artifacts:

---
# Phase 6 Learnings: Multi-Patient Support

## Decisions

### ARCH-01: Single-process multi-source architecture

One gluco-hub-rs process with N LLU sources, shared MQTT connection, isolated token caches. Chosen over multi-instance add-ons (HA does not support multiple instances of same slug) and multi-process spawn (resource waste). Implemented as HashMap<String, LluSourceConfig> in upstream config.rs with per-source poll tasks, token caches, and MQTT sinks.


**Rationale:** HA Supervisor limitation prevents multiple add-on instances of the same slug; multi-process spawn wastes resources vs shared connection; single-process with isolated poll tasks achieves both isolation and efficiency.

**Source:** UPSTREAM-SPEC.md, CONTEXT.md, STATE.md


---

### ARCH-02: Named accounts (TOML tables) over indexed arrays

Upstream multi-source config uses HashMap<String, LluSourceConfig> with named TOML tables (e.g. [sources.alice]) rather than a numbered array. Supports both shared-credential families (same LLU login, different patient_ids) and separate-account households (different emails).


**Rationale:** Named accounts provide self-documenting configuration, enable direct per-account reference in logs/topics, and naturally extend to both multi-patient (shared login) and multi-account (separate logins) use cases.

**Source:** UPSTREAM-SPEC.md, CONTEXT.md, STATE.md


---

### ARCH-03: API resilience phased before multi-patient

Phase 5 (API Resilience) shipped independently of Phase 6 (Multi-Patient) because quick wins like llu_version exposure and schema fingerprint logging did not require upstream multi-source changes.


**Rationale:** Multi-patient work is blocked on upstream gluco-hub-rs; independent improvements can ship without waiting. Reduces risk of all-or-nothing delivery.

**Source:** STATE.md


---

### Backward-compatible config schema with explicit mode detection

Add-on config.yaml supports both legacy single-account (flat llu_email/llu_password/llu_region/llu_patient_id) and new multi-account (llu_accounts list). Detection via shell check: if llu_accounts[0].name is empty → MODE=single, else MODE=multi.


**Rationale:** Existing v1.0 users must not be forced to rewrite configs on upgrade. Clear mode detection avoids ambiguous states.

**Source:** ADDON-DESIGN.md


---

### Per-account error isolation with shared transport

Each account gets its own poll task, token cache, MQTT sink with per-account topic prefix, and DLQ. One account's failure or rate limit only affects that account. MQTT connection is shared (broker disconnect affects all, deemed acceptable).


**Rationale:** Prevents credential failures or rate limits from cascading. Shared MQTT connection is acceptable as broker connectivity is a global concern.

**Source:** UPSTREAM-SPEC.md


---

### Per-patient MQTT topic naming with collision-free unique_id

MQTT topics use per-account prefix: <prefix>/<name>/glucose. unique_id includes account name. name is user-assigned and validated unique within config. Even with duplicate LLU patient_ids, entities are distinct because the add-on account name is the key.


**Rationale:** unique_id must be globally distinct per HA device. Keying on add-on account name handles the edge case of same patient added under two logins.

**Source:** ADDON-DESIGN.md


---

### Upstream spec written before implementation

UPSTREAM-SPEC.md was written as a detailed specification for gluco-hub-rs multi-source architecture before any code changes, covering config change, isolation model, MQTT naming, TOML format, backward compatibility, and acceptance criteria.


**Rationale:** Phase 6 is blocked on a different repository. A written spec enables async coordination with the upstream maintainer.

**Source:** PLAN.md, UPSTREAM-SPEC.md


---

## Lessons

### External upstream dependencies must be resolved before add-on implementation

Phase 6 was planned and designed but fully blocked because gluco-hub-rs only supports single-source. All 6 tasks marked 'Pending upstream'. The config struct was a hard prerequisite the add-on layer could not work around.


**Context:** The add-on wraps a Rust binary whose architecture constrains what the add-on can do. Upstream capability must be assessed before designing add-on features.

**Source:** PLAN.md, CONTEXT.md


---

### Verification is blocked when upstream dependency hasn't shipped

VERIFICATION.md documents that Phase 6 cannot be verified through automated testing. All 5 success criteria marked '[ ] ... needs upstream'. Verification gates cannot be cleared until the dependency lands.


**Context:** Verification docs for blocked phases serve as specification of what to check rather than evidence of working code.

**Source:** VERIFICATION.md


---

### Architecture research revealed hard HA constraints

Research discovered HA Supervisor does NOT support multiple add-on instances of the same slug (eliminated multi-instance approach). Also found LLU API supports multi-patient per login via connections endpoint, and gluco-hub-rs already parses connections but only polls one patient.


**Context:** Domain research before planning was essential; HA's multi-instance limitation and LLU's existing connections endpoint were discovered through codebase and platform analysis.

**Source:** CONTEXT.md


---

### Existing DLQ infrastructure already part-solved multi-patient

The existing DLQ already handles multi-patient via merge_dedup on (patient_id, timestamp). The sink layer was already prepared; only the source/poll layer needed upstream changes.


**Context:** Existing infrastructure may already handle parts of a new feature. Check existing patterns before designing from scratch.

**Source:** CONTEXT.md


---

### Field Optionality emerged as a prerequisite during implementation

During multi-source implementation, several fields (timestamp, value_in_mg_per_dl) needed to become Option<T> because different LLU accounts may report data at different cadences or with different fields present.


**Context:** Multi-source revealed that not all data sources produce identical response shapes. Optionality must be handled gracefully.

**Source:** SUMMARY.md


---

## Patterns

### Upstream specification as coordination artifact

When blocked on an external dependency, write a detailed spec doc describing the required API/architecture changes, config format, backward compat, and acceptance criteria for async coordination.


**When to use:** When a deliverable depends on changes in another repository you do not control, especially with a maintainer on a different schedule.

**Source:** PLAN.md, UPSTREAM-SPEC.md


---

### Backward-compatible config expansion

Extend config with a new optional list/section while keeping legacy flat fields intact. Detect mode via startup check on the new field's presence.


**When to use:** When adding multi-instance support to an existing single-instance system where existing users must not be forced to rewrite configs on upgrade.

**Source:** ADDON-DESIGN.md


---

### Per-account isolation with shared infrastructure

Spawn separate tasks per account (isolated poll, token cache, error handling) while sharing global infrastructure (MQTT connection, state directory). Key isolation boundaries: credentials, rate limits, token caches.


**When to use:** When a single process must serve multiple independent tenants with failure isolation but without the overhead of separate processes.

**Source:** UPSTREAM-SPEC.md


---

### User-assigned names as entity keys

Use a user-assigned account name (validated unique within config) as the key for MQTT topics, discovery unique_id, and device identity. Guarantees collision-free entities even if upstream IDs duplicate.


**When to use:** When mapping N external identities to MQTT entities needing guaranteed unique topic/discovery names, especially when the external ID may not be unique across accounts.

**Source:** ADDON-DESIGN.md


---

## Surprises

### Phase 6 both BLOCKED and COMPLETE simultaneously

PLAN.md says all tasks are 'Pending upstream' and VERIFICATION.md is BLOCKED, but SUMMARY.md reports Phase 6 as COMPLETE with all 10 requirements satisfied. The upstream changes (gluco-hub-rs 2026.606.0) were implemented as part of the same phase, but VERIFICATION.md was never revised to 'verified'.


**Impact:** Verification artifacts lagged behind implementation status. Documentation drift between status files.

**Source:** PLAN.md vs SUMMARY.md vs VERIFICATION.md


---

### HA Supervisor cannot run multiple add-on instances of the same slug

Before research, running multiple add-on instances (one per patient) might have seemed simplest. Discovery that HA explicitly prevents this forced the single-process multi-source architecture.


**Impact:** Fundamental architecture constraint discovered during research. Eliminated an entire design approach before implementation began.

**Source:** CONTEXT.md


---

### gluco-hub-rs already parsed connections list but only polled one patient

The upstream binary already parsed the LLU connections endpoint (returns multiple patients for family-sharing), but only used the first entry for polling. Multi-source changes were more about routing existing data to multiple sinks than adding new API calls.


**Impact:** Reduced upstream implementation scope significantly — splitting existing parsing across sources rather than adding new API integration.

**Source:** CONTEXT.md


---

### HTTP 429 handling was added during multi-source implementation

HTTP 429 rate-limit handling (3-retry with Retry-After backoff) was not in the original Phase 6 plan. Per-source polling with multiple accounts increases request rate, making rate-limit responses more likely.


**Impact:** Emerged as requirement ENH-05. Required adding send_with_retry to upstream auth.rs with Retry-After header parsing and exponential backoff.

**Source:** SUMMARY.md


---

### Schema fingerprint logging emerged independently during multi-source work

Schema fingerprint startup log (printing the TOML config schema fingerprint at startup for diagnostics) was not planned but was implemented during upstream changes, becoming requirement ENH-08.


**Impact:** Useful diagnostics feature discovered during implementation. Helps debug config mismatches between add-on layer and upstream binary.

**Source:** SUMMARY.md


---

### 141 upstream tests passed despite major architectural refactor

Refactoring config from single-source (Option<LluSourceConfig>) to multi-source (HashMap<String, LluSourceConfig>) while adding per-source tasks, sinks, token caches, 429 handling, and field optionality — all 141 existing tests still pass.


**Impact:** High confidence in upstream changes. Strong test coverage caught regressions during a major architectural refactor.

**Source:** SUMMARY.md


---
