---
phase: 01-verification-release-prep
reviewed: 2026-06-07T00:00:00Z
depth: deep
files_reviewed: 15
files_reviewed_list:
  - libre-glucose/run.sh
  - libre-glucose/config.yaml
  - libre-glucose/Dockerfile
  - libre-glucose/build.yaml
  - libre-glucose/translations/en.yaml
  - libre-glucose/translations/de.yaml
  - libre-glucose/DOCS.md
  - libre-glucose/README.md
  - libre-glucose/CHANGELOG.md
  - scripts/release.sh
  - tests/test-run-sh.sh
  - tests/test-check-config.sh
  - tests/mock-bashio.sh
  - SECURITY.md
  - Taskfile.yml
findings:
  critical: 0
  warning: 7
  info: 6
  total: 13
status: issues_found
---

# Phase 01: Deep Code Review Report

**Reviewed:** 2026-06-07T00:00:00Z
**Depth:** deep (cross-file analysis with import/call-chain tracing)
**Files Reviewed:** 15
**Status:** issues_found — 7 warnings, 6 info items

## Summary

Deep review of the Home Assistant Supervisor app wrapper for `gluco-hub-rs`. The codebase is a thin Bash + Docker + YAML layer: `run.sh` translates Supervisor options into `GLUCO_HUB__*` env vars, `config.yaml` defines the app manifest, and `release.sh` manages the CalVer release cadence. No business logic lives in this repo — all polling, MQTT, and discovery logic is upstream.

The implementation is **well-structured and defensive** where it matters: `set -euo pipefail` everywhere, idempotent CHANGELOG promotion, version-consistency guards in the release script, and meaningful test coverage for the ENV-variable mapping surface (the highest-risk area). The AppArmor profile is thorough with explicit denies and well-commented rationale for every permission.

**No critical/blocker findings.** The issues found are documentation staleness, test fragility, and hardening opportunities — all fixable without architectural changes.

---

## Warnings

### WR-01: DOCS.md `client_id` default value is stale

**File:** `libre-glucose/DOCS.md:43`
**Issue:** The configuration reference table lists `client_id` default as `gluco-hub-ha`, but `config.yaml` changed the default to `ha` in version 2026.516.1 (documented in CHANGELOG). Users reading DOCS.md for reference would use the wrong default value, producing the doubled-up entity name this change was meant to fix.

**Fix:**
```markdown
| `client_id` | string | `ha` | MQTT client id (1–23 chars…). Also appears in the HA discovery unique-id. |
```

---

### WR-02: DOCS.md "What the sensor exposes" section is stale

**File:** `libre-glucose/DOCS.md:48-50`
**Issue:** The paragraph reads:

> "State: current glucose in **mg/dL** (this is hard-coded upstream for V1; a future upstream patch will make mmol/L selectable for European users — the JSON payload already carries both units)."

The `glucose_unit` option (`mgdl` / `mmol`) was implemented (gluco-hub-rs PR #17, exposed in CHANGELOG under `[2026.516.1]` and `[2026.515.0]`). Users can already select `mmol` as their unit. This paragraph makes the add-on look like it lacks a feature it actually ships.

**Fix:**
```markdown
State: current glucose in the configured unit (**mg/dL** or **mmol/L**; default mg/dL).
The MQTT JSON payload always carries both `mgdl` and `mmol` fields regardless of the
configured unit — only the HA discovery entity's `unit_of_measurement` is affected.
```

---

### WR-03: `test-check-config.sh` default tag does not exist

**File:** `tests/test-check-config.sh:10`
**Issue:** The fallback tag `GLUCO_HUB_TAG="${GLUCO_HUB_TAG:-2026.514.0}"` does not correspond to any tagged release in this repo (only `v2026.516.1` and `v2026.516.2` exist). The upstream `ghcr.io/micschr0/gluco-hub` image may or may not have this tag — the earliest documented stable release is `2026.515.0`. If the tag is missing, the test fails with a Docker pull error, not a meaningful assertion failure. This makes the test brittle and confusing to debug.

Additionally, the test passes `GLUCO_HUB__SINK__MQTT__DISCOVERY_UNIT=mgdl` to a binary from `2026.514.0`, but this field was added in gluco-hub-rs PR #17 (first shipped in `2026.515.0`). The old binary may silently ignore unknown env vars (making the test pass vacuously for this field), or may reject them (making the test fail for the wrong reason).

**Fix:** Pin the default to the current release tag and keep it in sync with Renovate bumps. Alternatively, derive the tag from `build.yaml`'s `GLUCO_HUB_TAG` so it always matches the bundled upstream version:
```bash
GLUCO_HUB_TAG="${GLUCO_HUB_TAG:-$(grep -oP 'GLUCO_HUB_TAG:\s*"?\K[^"\s]+' libre-glucose/build.yaml)}"
```

---

### WR-04: AppArmor grants `dac_override` capability

**File:** `libre-glucose/apparmor.txt:80`
**Issue:** The profile grants `capability dac_override`, which bypasses all Unix discretionary access control (file permission) checks. This allows the process to read, write, or execute any file regardless of its ownership or mode bits — within the paths the AppArmor profile allows. Common in HA add-on profiles due to s6-overlay's UID/GID switching, but it is a powerful capability that would amplify the impact of a compromised `gluco-hub` binary. The profile already scopes `/data/** rw,`, so `dac_override` may be redundant for state writes.

**Fix:** Investigate whether `dac_override` is actually required. If s6-overlay needs it only during startup, consider dropping it after initialization. If it's needed for `/data` access, a more precise alternative is file ownership alignment (ensure the container UID owns `/data`). **Do not remove without testing** — s6-overlay v3 on the HA Debian base image may genuinely need it for the `setuid`/`setgid` transitions during service bring-up.

---

### WR-05: MQTT communication is hardcoded plaintext

**File:** `libre-glucose/run.sh:63`
**Issue:** `export GLUCO_HUB__SINK__MQTT__TLS="false"` is hardcoded. The Mosquitto add-on on the internal `hassio` bridge network is reachable in plaintext, and this is the standard HA add-on pattern. However, glucose readings are PHI. Any process on the same Docker bridge could potentially sniff MQTT traffic if the bridge network isolation is compromised.

**Fix:** Consider exposing a `mqtt_tls` boolean option (default `false` for backward compatibility) that allows users to enable TLS when they have a certificate infrastructure set up. This would require Mosquitto to be configured with TLS listeners, which is a user-side concern, but the add-on should not make it impossible.

---

### WR-06: `drift-check` Taskfile target does not validate config.yaml

**File:** `Taskfile.yml:25-37`
**Issue:** The `drift-check` task compares Dockerfile's `GLUCO_HUB_TAG` against build.yaml's `GLUCO_HUB_TAG`, but only *prints* config.yaml's `version:` without comparing it. Doc comment says "Assert Dockerfile / build.yaml / config.yaml carry the same upstream tag" but the implementation only checks two of the three. If Renovate fails to bump one of the three, or a manual edit introduces drift, `drift-check` would not catch a config.yaml mismatch.

**Fix:** Add the third comparison:
```bash
if [ "$DOCKERFILE_TAG" != "$CONFIG_VERSION" ]; then
  echo "DRIFT: Dockerfile != config.yaml" >&2
  exit 1
fi
```
Alternatively, if the intentional design is that config.yaml's `version:` may legitimately diverge during development (pre-release suffix), document this explicitly in the drift-check output.

---

### WR-07: HEALTHCHECK depends on bash `/dev/tcp` compile-time feature

**File:** `libre-glucose/Dockerfile:55-56`
**Issue:** The HEALTHCHECK uses `bash -c '</dev/tcp/127.0.0.1/8080'`. The `/dev/tcp` pseudo-filesystem is a bash compile-time option (`--enable-net-redirections`). While the HA Debian base image ships bash with this enabled, it is an implicit assumption. If the base image maintainers change their bash build configuration, the HEALTHCHECK would silently fail (every probe returns non-zero, container marked unhealthy). No fallback tool (e.g., `curl`, `nc`) is installed.

**Fix:** Add a comment documenting the bash dependency, or use a more portable probe. Since the base image is controlled by the HA project, the risk is low, but it deserves explicit acknowledgement. Alternative:
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/bin/sh", "-c", "exec 3<>/dev/tcp/127.0.0.1/8080 || exit 1"]
```
(Note: `/bin/sh` on Debian is dash, which does NOT support `/dev/tcp`. Keep bash.)

---

## Info

### IN-01: GNU-isms in release.sh reduce portability

**File:** `scripts/release.sh:66,68,136`
**Issue:** `date -u +%-m` (no-zero-padding flag), `date -u +%-d`, and `sed -i.bak` are GNU extensions. The script uses `#!/usr/bin/env bash` and runs on Linux CI, so this is not a current bug. However, a macOS developer running `task release:dry` locally would hit failures.

**Fix:** Document that `scripts/release.sh` requires GNU coreutils and GNU sed. Add a guard at the top:
```bash
if ! date --version 2>/dev/null | grep -q GNU; then
    echo "release.sh requires GNU date and GNU sed (Linux)." >&2
    exit 1
fi
```

---

### IN-02: Secrets exposed as environment variables

**File:** `libre-glucose/run.sh:40-41,62-63`
**Issue:** `LLU_PASSWORD` and `MQTT_PASSWORD` are exported as environment variables, making them visible in `/proc/<pid>/environ` to any process in the container with sufficient privileges. This is inherent to the bashio → env-var pattern used by virtually all HA add-ons. The AppArmor profile restricts `/proc` access, but any process sharing the container's PID namespace (including the gluco-hub binary itself) can read them.

**Fix:** This is a "known accepted risk" for the HA add-on ecosystem, not an actionable bug. The AppArmor profile already denies `/proc/kcore` and `/proc/sys/kernel/**` writes. Document in SECURITY.md that credentials live in environment variables for the lifetime of the container.

---

### IN-03: Container runs as root

**File:** `libre-glucose/Dockerfile` (no `USER` directive)
**Issue:** The Dockerfile does not specify a non-root user. HA Supervisor manages container isolation through its own mechanisms, and the HA Debian base images default to root. The AppArmor profile confines the process, but running as root inside the container means any AppArmor bypass (e.g., a kernel vulnerability) gives full root access.

**Fix:** This is a HA ecosystem convention — most add-ons run as root and rely on Supervisor + AppArmor for isolation. The profile's explicit denies (`deny mount`, `deny ptrace`, `deny capability sys_admin`) provide defense in depth. Consider adding a comment acknowledging this tradeoff.

---

### IN-04: Test coverage gap — `device_name` positive case untested

**File:** `tests/test-run-sh.sh:65-69`, `tests/mock-bashio.sh:37`
**Issue:** The test asserts that `GLUCO_HUB__SINK__MQTT__DEVICE_NAME` is NOT exported when `device_name` is empty. It does not test the positive case where `device_name` is non-empty and should be exported. The conditional export in `run.sh:70-72` has only its negative branch covered.

**Fix:** Add a variant of the mock `bashio::config` that returns a non-empty `device_name`, or parameterize the mock to accept a test fixture. A simpler approach: add a second test run with `device_name` set.

---

### IN-05: DOCS.md references `panel_admin` but config.yaml omits it

**File:** `libre-glucose/DOCS.md:78`
**Issue:** The Clock View section says "visible to admin users only — see `panel_admin` in the add-on config". However, `config.yaml` does not set `panel_admin: true`; it relies on the Supervisor default (admin-only when `ingress: true`). The config.yaml comment (line 46) explains this design decision, but the DOCS.md reference to `panel_admin` as if it's an explicit config key could confuse users who look for it.

**Fix:**
```markdown
opened directly from the Home Assistant sidebar entry (visible to admin users only
by default when Ingress is enabled, per the Supervisor's default `panel_admin` behaviour).
```

---

### IN-06: No integrity verification of copied upstream binary

**File:** `libre-glucose/Dockerfile:42`
**Issue:** `COPY --from=upstream /usr/local/bin/gluco-hub /usr/local/bin/gluco-hub` copies the binary without verifying its integrity. The upstream image is pulled from `ghcr.io/micschr0/gluco-hub:${GLUCO_HUB_TAG}` which is signed with cosign (keyless) and has SLSA provenance — but the Docker build process itself does not verify these attestations. A compromised upstream image (registry attack, tag mutation) would be copied blindly.

**Fix:** This is mitigated by the upstream's signing infrastructure (cosign + SLSA), and Docker's content trust (if enabled). For a defense-in-depth improvement, pin the upstream image by digest in a separate verification step, or document that cosign verification should be performed before building. This is a "nice to have" hardening measure.

---

_Reviewed: 2026-06-07T00:00:00Z_
_Reviewer: Claude (DeepReviewPhase1)_
_Depth: deep_
