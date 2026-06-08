# Plan: Phase 1 — Verification & Release Prep

**Phase:** 1 — Verification & Release Prep
**Goal:** Complete verification of existing codebase, establish GSD planning infrastructure, run tests, and prepare for v1.0 release.
**Requirements:** BRDG-10, BRDG-11, BRDG-12, BRDG-13

## Tasks

### Task 1.1: Establish GSD Planning Infrastructure (BRDG-13)

**Description:** Ensure GSD planning infrastructure is properly established with all artifacts committed and STATE.md tracking active.

**Files:**
- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/config.json`

**Type:** infrastructure

**Acceptance:**
- [ ] All `.planning/` artifacts exist and are committed
- [ ] STATE.md frontmatter reflects correct phase and progress
- [ ] REQUIREMENTS.md traceability maps each BRDG requirement to Phase 1

---

### Task 1.2: Run Test Suite (BRDG-10)

**Description:** Execute the existing unit and integration test suites. Fix any failures and ensure all tests pass.

**Files:**
- `tests/test-run-sh.sh`
- `tests/test-check-config.sh`
- `tests/mock-bashio.sh`

**Type:** verification

**Acceptance:**
- [ ] Unit tests (`test-run-sh.sh`) pass
- [ ] Integration tests (`test-check-config.sh`) pass
- [ ] Any test failures are diagnosed and fixed
- [ ] Test output is documented

---

### Task 1.3: Code Review (BRDG-10, BRDG-11)

**Description:** Review all source files for bugs, security issues, and code quality problems. Fix any critical or warning-level findings.

**Files:**
- `run.sh`
- `config.yaml`
- `Dockerfile`
- `build.yaml`
- `translations/en.yaml`
- `translations/de.yaml`

**Type:** verification

**Acceptance:**
- [ ] All source files reviewed for correctness
- [ ] No critical or warning-level issues remain
- [ ] Code follows existing patterns and conventions

---

### Task 1.4: Verify Release Pipeline (BRDG-12)

**Description:** Review the release script (`release.sh`) and verify it can execute end-to-end. Ensure CHANGELOG.md reflects the current state.

**Files:**
- `release.sh`
- `CHANGELOG.md`
- `config.yaml` (version field)

**Type:** infrastructure

**Acceptance:**
- [ ] `release.sh` reviewed for correctness
- [ ] CHANGELOG.md entries are accurate and up-to-date
- [ ] Version in `config.yaml` matches current state

---

### Task 1.5: Update README and Documentation (BRDG-11)

**Description:** Verify README.md accurately reflects the current project state and installation steps.

**Files:**
- `README.md`
- `DOCS.md`
- `SECURITY.md`

**Type:** documentation

**Acceptance:**
- [ ] README installation steps are accurate
- [ ] Documentation references are current
- [ ] Security policy is accurate

---

### Task 1.6: Verification and Summary (BRDG-10, BRDG-11, BRDG-12, BRDG-13)

**Description:** Final verification pass: confirm all tasks are complete, write SUMMARY.md, write VERIFICATION.md.

**Files:**
- `.planning/phases/01-verification-release-prep/01-SUMMARY.md`
- `.planning/phases/01-verification-release-prep/01-VERIFICATION.md`

**Type:** verification

**Acceptance:**
- [ ] All prior tasks completed
- [ ] SUMMARY.md written with accomplishments
- [ ] VERIFICATION.md written with status and evidence
- [ ] STATE.md updated to reflect phase completion
