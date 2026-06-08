# Phase 05: API Resilience - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning
**Mode:** Infrastructure phase (smart discuss skipped)

<domain>
## Phase Boundary

Bridge withstands LibreLink Up API changes — version header bumps, HTTP 429 rate limiting, field renames — without data loss or operator emergency.

Requirements: ENH-05, ENH-06, ENH-07, ENH-08, ENH-09
</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
Add-on layer scope (phase 5):
- ENH-06: Expose llu_version in config.yaml → run.sh env export (trivial add-on plumbing)
- ENH-08: Log schema fingerprint at startup in run.sh (JSON field name inventory)

Upstream gluco-hub-rs scope:
- ENH-05: HTTP 429 handling with Retry-After (upstream Rust change)
- ENH-07: Field Optionality (upstream Rust change)
- ENH-08: Schema fingerprint generation (upstream Rust change)

### Key Constraint
Phase 6 (Multi-Patient) depends on upstream changes. Phase 5 items that are add-on-only can ship independently. Items requiring upstream coordination must be tracked as blockers for Phase 5 completion.
</decisions>

<code_context>
## Existing Code Insights

- `libre-glucose/config.yaml` — HA add-on schema. New llu_version option goes here (str, nullable)
- `libre-glucose/run.sh` — bashio config reads. New GLUCO_HUB__SOURCE__LLU__VERSION export
- Upstream `gluco-hub-rs` — source.rs handles LLU HTTP client; sink_router.rs handles error propagation
- Research: ARCHITECTURE.md §4 covers API resilience patterns

### Integration Points
- llu_version is already supported upstream via env var — add-on just needs to expose the config option
- Schema fingerprint: add-on logs the expected fields; upstream generates the actual fingerprint
- Backward compatibility: existing configs without llu_version must work identically
</code_context>

<specifics>
## Specific Ideas

### Success Criteria (from ROADMAP)
1. llu_version exposed in add-on config UI
2. Bridge handles HTTP 429 with Retry-After backoff
3. Schema fingerprint logged at startup
4. Critical LLU JSON fields tolerate renames without crashing or zero-value readings
5. Backward compatibility — existing v1.0 configs work identically
</specifics>

<deferred>
## Deferred Ideas

None — all within phase scope.
</deferred>
