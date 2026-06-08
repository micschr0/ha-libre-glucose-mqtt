---
phase: 5
phase_name: "API Resilience"
project: "Libre Glucose MQTT Bridge"
generated: "2026-06-07"
counts:
  decisions: 7
  lessons: 4
  patterns: 6
  surprises: 4
missing_artifacts:

---
# Phase 5 Learnings: API Resilience

## Decisions

### Add-on-only scope for Phase 5 deliverables

Phase 5 split work: add-on-side items (llu_version exposure, schema fingerprint logging, backward compat verification) ship independently; upstream items (429 handling, field Optionality, Rust-side fingerprint) tracked as dependencies in a dedicated document.


**Rationale:** Add-on quick wins don't need to wait on upstream gluco-hub-rs changes; Phase 5 shippable independently.

**Source:** 05-PLAN.md (Task 5.1–5.4 breakdown, Context paragraph)


---

### llu_version as nullable string with empty default

New config option is `str?` defaulting to empty string. Empty = use upstream default.


**Rationale:** Preserves backward compatibility with existing v1.0 configs that lack the field.

**Source:** 05-PLAN.md (Task 5.1: 'Field is nullable (empty = use upstream default)'), 05-VERIFICATION.md


---

### Env var interface for config passthrough

Config exposed as `GLUCO_HUB__SOURCE__LLU__VERSION` env var — bashio reads config, run.sh exports var.


**Rationale:** Upstream gluco-hub-rs already supports this env var; add-on just needed the config plumbing.

**Source:** 05-PLAN.md (Task 5.1: 'Upstream gluco-hub-rs already supports this env var'), 05-SUMMARY.md


---

### Schema fingerprint split: add-on logs expected fields, upstream generates actual

Add-on side logs a sorted list of expected LLU JSON field names at startup. Upstream side generates actual fingerprint from wire schema separately.


**Rationale:** Add-on can ship independently without waiting for upstream Rust change; operators still get cross-version fingerprint comparison.

**Source:** 05-PLAN.md (Task 5.2 vs Task 5.3), 05-CONTEXT.md (decisions section)


---

### Upstream dependencies documented as tracking spec

Created 05-UPSTREAM-TRACKING.md with per-item code pointers and acceptance criteria for upstream maintainer.


**Rationale:** Kept Phase 5 completable without blocking on other repo; gives upstream maintainer an actionable reference.

**Source:** 05-PLAN.md (Task 5.3), 05-UPSTREAM-TRACKING.md


---

### Phase 5 ships before Phase 6

ARCH-03 decision: API resilience additive items (llu_version, fingerprint) ship independently of upstream multi-source work. Phase 5 add-on items complete while Phase 6 awaits upstream.


**Rationale:** Phase 6 depends on upstream multi-source support; no reason to hold Phase 5's independentshipping items.

**Source:** 05-CONTEXT.md (ARCH-03), 05-STATE.md


---

### Backward compat verified via explicit test assertion

Test asserts `GLUCO_HUB__SOURCE__LLU__VERSION` is NOT exported when `llu_version` is unset/empty. All 19 existing env var assertions still pass.


**Rationale:** Existing v1.0 configs must work identically after the change. Test proves no regression.

**Source:** 05-SUMMARY.md (accomplishments #3), 05-VERIFICATION.md (criterion #3)


---

## Lessons

### Upstream dependencies need explicit tracking artifacts

Three of five ENH requirements were blocked on upstream gluco-hub-rs changes. Creating a dedicated tracking doc (05-UPSTREAM-TRACKING.md) with code pointers and acceptance criteria let Phase 5 still ship add-on items without waiting.


**Context:** Discovered during planning that ENH-05, ENH-07, and ENH-08 (Rust side) could not be implemented in this repo.

**Source:** 05-PLAN.md (Task 5.3), 05-UPSTREAM-TRACKING.md, 05-SUMMARY.md (requirements table)


---

### Nullability enables backward compat without ceremony

Making `llu_version` optional with empty default meant existing configs without it continued working identically. The backward-compat test passed trivially because the null path was the same code path as before.


**Context:** Adding a new config option risked breaking existing configs; the backward-compat test confirmed no regression.

**Source:** 05-SUMMARY.md (accomplishments #3), 05-VERIFICATION.md (criterion #3)


---

### Add-on layer is thin wiring, not business logic

All actual resilience logic (field parsing, HTTP handling) lives upstream in gluco-hub-rs. The add-on only exposes config options via bashio reads and env var exports. The env var export pattern repeats across config options.


**Context:** Phase 5 revealed that the add-on's job is configuration passthrough; real behavior changes require upstream changes.

**Source:** 05-PLAN.md (Context: 'Core resilience logic lives upstream'), 05-SUMMARY.md (accomplishments)


---

### Milestone v1.1 completed with 2 phases

STATE.md records milestone v1.1 as complete with 2 plans, 100% progress (Phase 5 + one earlier phase). Phase 5 was the second phase of the enhancement milestone.


**Context:** Tracking shows the project completed its second milestone.

**Source:** 05-STATE.md (progress section)


---

## Patterns

### Nullable string config with empty default

Add a config option as `str?` defaulting to empty string. Empty/unset = use upstream default. Preserves backward compatibility with existing configs that lack the field.


**When to use:** Adding new optional configuration where upstream has its own default and existing configs must work unmodified.

**Source:** 05-PLAN.md (Task 5.1 acceptance), 05-SUMMARY.md, 05-VERIFICATION.md


---

### Config → env var passthrough

bashio reads config option from HA add-on → run.sh exports env var with a name matching upstream's expected variable (e.g. `GLUCO_HUB__SOURCE__LLU__VERSION`). Thin wiring layer.


**When to use:** Add-on needs to surface a config option that an upstream component already supports via env var.

**Source:** 05-PLAN.md (Task 5.1: 'export env var if set'), 05-SUMMARY.md


---

### Upstream tracking document

When work depends on another repo, create a dedicated tracking doc with file paths, code pointers, and per-item acceptance criteria. Gives upstream maintainer an actionable reference without blocking current phase.


**When to use:** Phase scope includes items blocked on external repo changes; phase must ship independently.

**Source:** 05-PLAN.md (Task 5.3), 05-UPSTREAM-TRACKING.md


---

### Split phase across repo boundaries

Identify which items are completable within the current repo and which need upstream changes. Ship add-on items independently; track upstream items as dependencies. Phase still delivers value.


**When to use:** Feature touches both an add-on layer and an upstream library; upstream maintainer is a different team/rhythm.

**Source:** 05-PLAN.md (Task split), 05-CONTEXT.md (decisions section)


---

### Bilingual translations per config option

Every new config option gets label and description in both en.yaml and de.yaml in parallel.


**When to use:** Adding a new configurable field to a multilingual HA add-on.

**Source:** 05-PLAN.md (Task 5.1: translations), 05-SUMMARY.md (files changed)


---

### Startup diagnostic logging for API contract

Log sorted expected API field names at startup. Operators can compare fingerprints across versions to detect API changes.


**When to use:** System depends on external API with field names that could change; need operator-visible early warning.

**Source:** 05-PLAN.md (Task 5.2), 05-VERIFICATION.md (criterion #2)


---

## Surprises

### Upstream already supported the env var

Task 5.1 notes 'Upstream gluco-hub-rs already supports this env var — the add-on just doesn't expose it yet.' This made the config exposure trivial plumbing rather than a coordinated change.


**Impact:** Positive — reduced scope to pure add-on config wiring. No upstream PR needed for ENH-06.

**Source:** 05-PLAN.md (Task 5.1 description)


---

### Three of five ENH requirements pending upstream

ENH-05 (429 handling), ENH-07 (field Optionality), and ENH-08 (Rust-side fingerprint) all depend on upstream gluco-hub-rs changes. Only 2/5 requirements fully completable within this repo. Phase was still considered shippable.


**Impact:** Reduced completable scope significantly but planning upfront prevented scope creep or blocked delivery.

**Source:** 05-PLAN.md (Task 5.3), 05-SUMMARY.md (requirements table), 05-VERIFICATION.md (criteria 4-5)


---

### Backward compat test revealed zero breakage

Adding a new config option and export variable broke none of the 19 existing env var assertions. The nullable design with empty default produced a clean null path identical to the pre-existing code path.


**Impact:** Confirmed backward-compat design was correct; no regression fix needed.

**Source:** 05-SUMMARY.md (accomplishments #3), 05-VERIFICATION.md (criterion #3)


---

### Phase 5 shipped before Phase 6 despite dependency chain

ARCH-03 explicitly ordered API resilience work (Phase 5) before multi-source (Phase 6), even though Phase 6 depends on upstream changes. The independence was by design, not an accident.


**Impact:** Enabled parallelization — Phase 5 add-on items shipped while upstream work for Phase 6 is in progress.

**Source:** 05-CONTEXT.md (ARCH-03), 05-STATE.md (Current Position, Blockers/Concerns)


---
