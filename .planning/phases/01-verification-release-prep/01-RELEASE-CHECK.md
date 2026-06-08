# Release Check — Phase 1

## Verification Date
2026-06-07

## Files Reviewed
- `scripts/release.sh`
- `libre-glucose/CHANGELOG.md`
- `libre-glucose/config.yaml`

---

## 1. `libre-glucose/config.yaml` — Version Field

**Status:** ✅ Correct

| Field | Value |
|---|---|
| `version:` | `"2026.516.2"` |
| `name:` | `Libre Glucose MQTT Bridge` |
| `slug:` | `libre-glucose` |
| `image:` | `ghcr.io/micschr0/libre-glucose` |

- Version string matches the latest CHANGELOG entry (2026.516.2).
- Manifest is well-formed per HA Supervisor addon config spec.
- All options and schema fields are syntactically valid.
- `init: false`, `ingress: true`, `services: [mqtt:need]` — consistent with design intent.

---

## 2. `libre-glucose/CHANGELOG.md` — Version Entries & Descriptiveness

**Status:** ✅ Correct

### Version coverage

| Version | Date | Present | Matches `config.yaml` |
|---|---|---|---|
| **2026.516.2** | 2026-05-16 | ✅ Line 10 | ✅ |
| 2026.516.1 | 2026-05-16 | ✅ Line 30 | — |
| 2026.515.0 | (initial) | ✅ Implicit in provenance | — |
| Unreleased | — | ✅ Section stub present | — |

### Quality assessment per section

- **Upstream pin bumps** reference specific gluco-hub-rs PR numbers (#22, #20, #18, #19, #17). Good.
- **Security entries** detail AppArmor root cause analysis (s6 v2→v3 shebang incompatibility, `rix` rationale, ELF vs shebang distinction, AppArmor docs citations). High quality.
- **Disclaimer wording changes** are tracked across all 4 files (`README.md`, `DOCS.md`, `SECURITY.md`, `libre-glucose/README.md`) with precise descriptions. Good.
- **Structural additions** (Taskfile, release.sh, CI, pre-built GHCR image) are documented. Good.
- **Known limitations** section persists between releases — not dropped. Good.
- **`[Unreleased]` section** is present as a `## [Unreleased]` heading (line 8) with no body content yet. Idle state before next changelog promotion. Good.

---

## 3. `scripts/release.sh` — Script Correctness

**Status:** ✅ Correct (with minor caveats documented below)

### Flag parsing

| Flag | Behavior | Correct? |
|---|---|---|
| _(none)_ | Compute today's CalVer; adopt config.yaml pre-bump if higher (default mode) | ✅ |
| `--dry-run` | Compute + log + exit before any destructive action | ✅ |
| `--patch` | Bump PATCH from highest same-day tag | ✅ |
| `--rc` | Find next free `-rc.N` suffix | ✅ |
| `--unknown` | `exit 2` with message | ✅ |

Only the first positional arg is inspected; combining flags (e.g. `--dry-run --rc`) is not handled — `$1` consumes first flag, extra flags fall into the else branch → `exit 2`. This is acceptable; flags are mutually exclusive by design.

### Git tag logic

- Computes CalVer base from UTC date.
- `minor = month * 100 + day` → e.g. May 16 = `516`. ✅ Matches CHANGELOG pattern `2026.516.2`.
- Patch computation:
  - Default mode: PATCH=0 if no same-day tag; else PATCH = highest existing patch + 1 (strips `-rc.N` suffix).
  - `--patch`: requires an existing same-day tag; increments from highest (strips `-rc.N`).
  - Pre-bump adoption: if config.yaml version > computed version (in default/dry mode), adopt config.yaml value. ✅
  - Patch/RC modes deliberately override the pre-bump. ✅
- Tag format: `v${version}` → e.g. `v2026.516.2`. Annotated (`git tag -a`). ✅

### Docker build flow

- The script does **not** build any Docker image. It tags, commits, pushes, and delegates the build to `.github/workflows/release.yml` (noted on line 193). This is the intended split. ✅

### Error handling

| Guard | Mechanism | Correct? |
|---|---|---|
| `set -euo pipefail` | Top of script | ✅ |
| Dirty working tree | `git status --porcelain` check → `exit 1` | ✅ |
| Branch must be `main` | `git rev-parse --abbrev-ref HEAD` → `exit 1` | ✅ |
| Config.yaml update verification | `grep -q "^version: \"${version}\""` after sed → `exit 1` | ✅ |
| CHANGELOG promotion verification | `grep -q "^## \[${version}\]"` after awk → `exit 1` | ✅ |
| No diff → skip commit | `git diff --cached --quiet` → tag current HEAD | ✅ |
| Dry-run exits 0 early | Before any write | ✅ |

### Caveats (non-blocking)

1. **GNU-specific date syntax.** `date -u +%-m` / `%-d` strips leading zeroes via `%-`. This is GNU date only — BSD/macOS `date` does not support `%-`. Acceptable: target environment is an HA Supervisor/make container (Linux, GNU coreutils). Script would fail on macOS out of the box.

2. **GNU-specific sed.** `sed -i.bak` is GNU-style in-place. BSD sed uses `sed -i '' -e …`. Same rationale — Linux target only.

3. **No `--no-verify` on commit.** Line 187: `git commit -m "chore: release ${tag}"`. If the repo has pre-commit hooks (e.g. shellcheck on release.sh), they could block the release commit. No hooks are currently present in the repo. Low risk.

4. **No post-push failure handling.** If `git push` fails after the tag is created locally (line 193), the script exits from `set -e` with a local tag that has no upstream counterpart. Operator would need to `git push origin $tag` manually. Acceptable for a maintainer-run script.

---

## Summary

| Component | Status |
|---|---|
| `config.yaml` version | ✅ `2026.516.2` — correct |
| `CHANGELOG.md` matches | ✅ Entry `[2026.516.2] - 2026-05-16` present |
| `CHANGELOG.md` quality | ✅ Descriptive entries with PR references and rationale |
| `release.sh` logic | ✅ Correct: flag parsing, tag computation, pre-bump adoption, guards |
| `release.sh` hygiene | ⚠️ Minor: GNU-only syntax, no pre-commit bypass, no push-retry |
