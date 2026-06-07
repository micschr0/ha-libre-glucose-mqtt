---
overall_score: 52/100
verdict: NEEDS WORK
critical_gap_count: 3
---

# Phase 6 Eval Review: Multi-Patient Support

**Audited:** 2026-06-07
**Project:** ha-libre-glucose-mqtt (non-AI — bridge wrapping gluco-hub-rs)
**Phase Scope:** Multi-account TOML config, per-source MQTT topics, schema fingerprint

## Context

This project has NO AI/LLM components (no prompts, no RAG, no agents, no LLM judges, no
hallucination risk). Every dimension from ai-evals.md that targets AI behavior scores N/A.

---

## Evaluation Dimensions

### 1. Testing Coverage (Score: 50/100 — PARTIAL)

**Evidence:**

- **Single-account ENV path**: `tests/test-run-sh.sh` asserts 19 env var names + spellings
  via mocked bashio (lines 48-68). Tests empty-option guards (lines 84-89). Runs on every CI
  push/PR (`.github/workflows/ci.yml` line 220).
- **check-config integration test**: `tests/test-check-config.sh` feeds env vars into
  `gluco-hub check-config` via Docker, catching schema mismatches between run.sh and the
  upstream binary.
- **Mock bashio**: `tests/mock-bashio.sh` covers every `bashio::config` key and
  `bashio::services` call used in single-account mode.

**Gaps:**

- **Zero tests for multi-account TOML path**. `test-run-sh.sh` only tests single-account
  env var export; there is no test file or test function that exercises the
  `llu_accounts|length > 0` branch (lines 103-148 of run.sh). Critical because:
  - Lines 120-121 reference undefined shell variables (`${MQTT_USER}`, `${MQTT_PW}`)
    instead of the actual variables (`${MQTT_USERNAME}`, `${MQTT_PASSWORD}`). This bug
    causes the TOML config to contain empty `username`/`password` fields, making MQTT
    auth fail silently in multi-account mode.
  - No test validates the generated TOML syntax or schema.
- **No `check-config` test for multi-account config**. `test-check-config.sh` only tests
  the single-account env-vars path.
- **No upstream integration test** — the multi-account path requires `gluco-hub --config
  /tmp/gluco-hub.toml` and should be validated against the actual upstream binary.
- **Field Optionality (ENH-07)** is mentioned as handled upstream (summary says
  `Option<T>` fields), but no add-on-layer test verifies that empty optional fields in
  `llu_accounts[*].patient_id`, `llu_accounts[*].version` are correctly omitted from the
  generated TOML (lines 141-143 of run.sh).

### 2. CI/CD Quality (Score: 70/100 — GOOD)

**Evidence:**

- **Lint pyramid runs in CI**: addon-linter (`frenck/action-addon-linter`), yamllint,
  hadolint, shellcheck, AppArmor parser validation. All pass on every push/PR (ci.yml).
- **Version drift check**: Compares `Dockerfile ARG GLUCO_HUB_TAG`, `build.yaml
  GLUCO_HUB_TAG`, and `config.yaml ingress_port` against `run.sh` bind port (ci.yml
  lines 42-97). Catches one manual-edit drift path.
- **Docker build smoke**: `ci.yml` builds `libre-glucose:ci` with full multi-arch build args
  (lines 171-205). `release.yml` publishes final multi-arch images with cosign signing +
  SLSA attestation.
- **CVE scanning**: Grype scans built image with `severity-cutoff: critical` on CI, SARIF
  uploaded to GitHub Security (ci.yml lines 245-294).
- **Workflow security**: `step-security/harden-runner` on every CI step; `zizmor` scan
  (ci.yml line 226) for GitHub Actions injection issues.
- **Renovate**: Self-hosted, daily schedule; custom regex managers keep Dockerfile/build.yaml/
  config.yaml upstream tags in lockstep.
- **Release workflow**: Native arm64 runner (no QEMU), cosign keyless signing, SLSA
  attestation, GitHub Release with changelog extraction.

**Gaps:**

- **No CI job exercises the multi-account TOML path**. The env-mapping-smoke job (ci.yml
  lines 207-224) only runs single-account tests. No step validates generated TOML against
  `gluco-hub check-config`.
- **No drift check for config.yaml version vs build.yaml bug**: ci.yml version-consistency
  explicitly does NOT compare `config.yaml version:` against `build.yaml GLUCO_HUB_TAG`
  (comment at lines 60-65 says "informational" during pre-release). In steady state all
  three should match, but no automated gate enforces it.
- **Translation update not validated in CI** — no job verifies that `translations/en.yaml`
  and `translations/de.yaml` are in sync with `config.yaml schema`.

### 3. Error Handling (Score: 45/100 — PARTIAL)

**Evidence:**

- **MQTT service guard**: `run.sh` line 17 calls `bashio::exit.nok` if Mosquitto is
  unavailable. Tested in mock-bashio via `bashio::services.available('mqtt')` returning 1.
- **Required field validation**: `llu_email` and `llu_password` are checked for emptiness
  (lines 45-50) with clear error messages. Tested in `test-run-sh.sh` (lines 84-89 check
  that empty options are NOT exported).
- **Upstream field Optionality (ENH-07)**: `Option<T>` for timestamp, value_in_mg_per_dl means
  the Rust binary handles missing JSON fields gracefully rather than crashing.
- **Upstream HTTP 429 handling (ENH-05)**: 3-retry with Retry-After backoff in upstream
  `auth.rs::send_with_retry`. Implemented as part of this phase.
- **Per-source error isolation**: Each account gets its own poll task, token cache, and
  MQTT sink. One account's 401/429 does not block others (design in UPSTREAM-SPEC.md).

**Gaps:**

- **MQTT_USER/MQTT_PW undefined variables** (lines 120-121 of run.sh). In multi-account
  mode, `gluco-hub.toml` gets empty MQTT credentials. Because bash is invoked with
  `set -euo pipefail`, accessing an undefined variable would normally abort the script
  — HOWEVER, the variable is referenced inside a HEREDOC (`<<TOML`), which is NOT an
  error under `set -u`. The heredoc simply expands the undefined variable to empty string.
  Result: multi-account mode silently writes invalid MQTT credentials and the binary runs but
  cannot authenticate to Mosquitto. This is a **critical runtime bug**.
- **No per-account TOML section validation**: If `bashio::config "llu_accounts[${i}].name"`
  returns empty for an entry, the TOML section header becomes `[source.sources.]` which
  is invalid TOML. No guard against this.
- **No fallback when TOML generation fails**: If writing `/tmp/gluco-hub.toml` fails (disk
  full, permissions), the script falls through to the single-account `exec` path at line 152
  without logging the fallback. This masks the failure and starts the binary with only
  the env-var config.
- **No `gluco-hub --config` validation**: The TOML is written but never validated with
  `gluco-hub check-config` before exec. A malformed TOML causes the `exec` to fail after
  the script's exit, with the only evidence being the container restart loop.

### 4. Config Validation (Score: 55/100 — ADEQUATE)

**Evidence:**

- **HA Supervisor schema validation**: `config.yaml` schema field (lines 110-133) enforces
  types, enums, regex (`match(^[A-Za-z0-9_-]{1,23}$)` for `client_id`), optional/nullable
  markers (`str?`), and integer ranges (`int(30,600)` for `poll_interval_secs`). The
  llu_accounts entry schema validates names, emails, passwords, regions, timezones per
  account. This catches bad config at the HA UI layer before run.sh ever runs.
- **`addon-linter` CI job** validates config.yaml against the HA add-on schema.
- **Required-field guards**: `llu_email` and `llu_password` checked in run.sh.
- **Upstream fingerprint logging**: startup log prints LLU JSON field names for
  operators to detect API changes across versions (run.sh line 101).

**Gaps:**

- **No TOML-level validation**: HA schema validates the input form, but there is no check
  that the generated `gluco-hub.toml` is syntactically valid. A future drift between
  the TOML template and what gluco-hub-rs expects would go undetected until runtime.
- **No post-merge config validation**: After the upstream changes land, there should be a
  CI step that generates a TOML from the config schema and pipe-checks it against
  `gluco-hub check-config`.
- **No translation coverage for multi-account**: The `llu_accounts` config options added
  in config.yaml lack corresponding labels/descriptions in `translations/en.yaml` and
  `translations/de.yaml`. The schema itself is correct, but users see unlabeled fields
  in the HA UI unless translations were added (not verified during audit).

### 5. Schema Compliance (Score: 45/100 — PARTIAL)

**Evidence:**

- **MQTT discovery unique_id per account**: Design in ADDON-DESIGN.md and UPSTREAM-SPEC.md
  specifies `gluco_hub_ha_{name}_glucose` format with collision-free guarantees. The
  `per_source = true` config (TOML line 125) instructs upstream to generate per-source
  discovery messages.
- **TOML section naming**: `[source.sources.{name}]` in run.sh line 137. Schema fingerprint
  logging at run.sh line 101 documents expected LLU JSON fields.
- **Config.yaml schema** validates llu_accounts entries with proper types.
- **Version consistency**: Dockerfile/build.yaml/config.yaml upstream tag alignment checked
  in ci.yml drift-check job.

**Gaps:**

- **MQTT_USER/MQTT_PW vs MQTT_USERNAME/MQTT_PASSWORD drift** (critical): The TOML template
  uses different variable names than the ones defined at lines 23-24. This is the exact
  kind of schema-level issue a schema-compliance check should catch.
- **TOML structure not validated against upstream binary config struct**:
  `[source.sources.{name}]` table format may not match `HashMap<String, LluSourceConfig>`
  in the actual upstream binary. The upstream spec (UPSTREAM-SPEC.md) proposed
  `[sources.{name}]`, but run.sh line 137 produces `[source.sources.{name}]`. One of
  these is wrong — only the actual upstream binary can confirm which. No CI step
  validates the generated TOML against `gluco-hub check-config`.
- **No `per_source` feature test**: `per_source = true` (line 125) is hardcoded in the
  TOML. If the upstream binary's sink config changes this field name or type, there is no
  test to detect the break.
- **Translation schema not verified**: No CI job verifies that every config.yaml schema
  entry has a corresponding translation key.

---

## Dimension Summary

| Dimension | Score | Evidence Basis | Critical Gaps |
|---|---|---|---|
| Testing Coverage | 50/100 | 19 env assertions pass; zero multi-account TOML tests | 0 TOML path tests; undefined var undetected |
| CI/CD Quality | 70/100 | Multi-lint, drift-check, CVE scan, cosign+SLSA, native arm64 | No multi-account CI step |
| Error Handling | 45/100 | MQTT guard, required-field checks, per-source isolation design | MQTT_USER undefined bug; no TOML validation |
| Config Validation | 55/100 | HA schema validation, required-field guards, fingerprint log | No TOML-level validation; no post-merge check |
| Schema Compliance | 45/100 | Named-account design, per_source, fingerprint log | MQTT_USER var name drift; TOML struct not validated |
| **Overall** | **52/100** | | **3 critical** |

All AI-specific dimensions (factual accuracy, hallucination, LLM judges, prompt engineering,
RAG, etc.): **N/A** — no AI/LLM components in this project.

---

## Critical Gaps (Must Fix Before Production)

1. **`${MQTT_USER}` / `${MQTT_PW}` undefined variables** — run.sh lines 120-121 use
   variable names that are never defined. They should be `${MQTT_USERNAME}` and
   `${MQTT_PASSWORD}`. Multi-account mode produces a TOML config with empty MQTT
   credentials, causing silent MQTT auth failure.

2. **No multi-account TOML tests** — Every multi-account validation path is exercised
   only at the "it compiles" level. Writing a `test-run-sh-multi.sh` that sets up mocked
   `llu_accounts` entries and asserts the generated TOML content would catch the
   MQTT_USER bug, empty-account-name issues, and per-source TOML structure.

3. **TOML generated, never validated** — run.sh writes `/tmp/gluco-hub.toml` but never
   calls `gluco-hub check-config --config /tmp/gluco-hub.toml` before exec. A CI job
   should generate a TOML from the config schema and pipe-check it against the upstream
   binary.

---

## Minor Gaps (Should Fix Soon)

- Add translations for `llu_accounts` fields in `translations/en.yaml` and `de.yaml` if
  not already present.
- Add CI drift check for `config.yaml version:` vs `build.yaml GLUCO_HUB_TAG` in addition
  to the existing Dockerfile-vs-build.yaml check.
- Add fallback logging when TOML generation fails before falling through to single-account path.

---

## Remediation Plan

1. Fix run.sh lines 120-121: `MQTT_USER` → `MQTT_USERNAME`, `MQTT_PW` → `MQTT_PASSWORD`.
2. Write `tests/test-run-sh-multi.sh` — smoke test that sources mock-bashio with
   `llu_accounts` config values, runs the multi-account branch of run.sh, and asserts
   the generated TOML contains correct MQTT credentials, per-source sections, and `per_source=true`.
3. Add CI job `env-mapping-smoke-multi` to `ci.yml` that runs the multi-account test.
4. Add a CI step that generates TOML from multi-account config and validates syntax with
   `gluco-hub check-config --config /dev/stdin` (or equivalent).

---

## Verification Status

All 5 success criteria from VERIFICATION.md remain blocked on upstream gluco-hub-rs
multi-source support. The add-on layer code is written but cannot be end-to-end verified
until the upstream binary accepts the new TOML format. The bugs above (particularly
gap #1) will cause runtime failures the moment someone tries multi-account mode — fix
before the upstream changes land.
