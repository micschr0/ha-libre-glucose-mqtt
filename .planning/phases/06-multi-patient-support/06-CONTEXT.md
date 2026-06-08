# Phase 06: Multi-Patient Support - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning (BLOCKED — upstream dependency)
**Mode:** Infrastructure phase

<domain>
## Phase Boundary

One add-on instance monitors multiple LibreLink Up accounts or patients, each with isolated MQTT entities, independent error recovery, and guaranteed collision-free discovery.

Requirements: ENH-01, ENH-02, ENH-03, ENH-04, ENH-10
</domain>

<decisions>
## Implementation Decisions

### BLOCKER
Phase 6 requires upstream gluco-hub-rs multi-source support (single binary serving N LLU accounts). Current upstream architecture is single-source only. This is tracked as a blocker in STATE.md.

### Architecture (from research)
- **ARCH-01**: Single-process multi-source in gluco-hub-rs — one process with N LLU sources, shared MQTT connection, isolated token caches
- **ARCH-02**: Named accounts (TOML config) rather than indexed arrays
- Per-patient MQTT entities with guaranteed unique unique_id

### Add-on layer scope (when upstream is ready)
- config.yaml: list schema for multiple accounts/patients
- run.sh: TOML config generation for multi-account
- MQTT topic naming: `<prefix>/<patient_id>/glucose`
</decisions>

<code_context>
## Existing Code Insights

- HA Supervisor does NOT support multiple add-on instances of same slug
- LibreLink Up supports multi-patient per login via family sharing (connections endpoint)
- gluco-hub-rs already parses connections list but only polls ONE patient
- MQTT discovery unique_id format: `gluco_hub_{client_id}_glucose` — must be per-patient
- Existing DLQ handles multi-patient via merge_dedup on (patient_id, timestamp)

### Integration Points
- config.yaml → list or auto-discovery schema for patient configs
- run.sh → TOML generation from list config
- Upstream: multi-source architecture (HashMap<String, LluSourceConfig>)
</code_context>

<specifics>
## Specific Ideas

### Success Criteria (from ROADMAP)
1. A single add-on instance monitors multiple LibreLink Up accounts/patients
2. Per-patient MQTT entities with globally distinct unique_id
3. HA auto-discovers glucose + trend sensors per patient as separate devices
4. One account's failure does not block others
5. Existing single-account v1.0 configs work identically
</specifics>

<deferred>
## Deferred Ideas

None — all within phase scope.
</deferred>
