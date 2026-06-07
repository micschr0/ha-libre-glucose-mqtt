#!/usr/bin/env bash
#
# Multi-account smoke test: run run.sh with llu_accounts config and assert
# the generated /tmp/gluco-hub.toml contains correct MQTT credentials,
# per-source sections, and per_source=true.
#
# Validates the TOML template — the second biggest risk surface in the
# wrapper after the ENV-name spelling (tested in test-run-sh.sh).

set -euo pipefail

cd "$(dirname "$0")/.."

TEST_STATE_PARENT="$(mktemp -d -t libre-glucose-multi.XXXXXX)"
TOML_CAPTURE="$(mktemp /tmp/lg-toml-capture.XXXXXX)"
trap 'rm -rf "${TEST_STATE_PARENT}"; rm -f "${TOML_CAPTURE}"' EXIT

# Build a modified run.sh that:
#  1. drops the bashio shebang
#  2. retargets /data/state to a writable temp dir
#  3. replaces the final `exec` with a stderr marker so the script returns
sed -e '1d' \
    -e "s|/data/state|${TEST_STATE_PARENT}/state|g" \
    -e 's|exec /usr/local/bin/gluco-hub.*|cp /tmp/gluco-hub.toml '"${TOML_CAPTURE}"'; echo "EXEC_CAPTURED" >\&2|' \
    libre-glucose/run.sh \
    > /tmp/run-multi.sh

# Remove any leftover from a prior run.
rm -f "${TOML_CAPTURE}" /tmp/gluco-hub.toml

# Run in subshell so set -euo pipefail inside run.sh doesn't leak.
(
    # Shellcheck-compatible bashio mock for two accounts.
    bashio::services.available() { return 0; }
    bashio::services() {
        case "${1}:${2}" in
            mqtt:host) echo "mock-mqtt.local" ;;
            mqtt:port) echo "1883" ;;
            mqtt:username) echo "mosquitto" ;;
            mqtt:password) echo "mqttpw" ;;
            *) echo "mock: unexpected services ${1}:${2}" >&2; return 1 ;;
        esac
    }
    bashio::config() {
        case "$1" in
            llu_email) echo "fallback@example.com" ;;
            llu_password) echo "fallbackpw" ;;
            llu_region) echo "EU" ;;
            llu_timezone) echo "UTC" ;;
            llu_version) echo "" ;;
            llu_patient_id) echo "" ;;

            poll_interval_secs) echo "60" ;;
            device_name) echo "" ;;
            glucose_unit) echo "mgdl" ;;
            topic_prefix) echo "gluco-hub/ha" ;;
            client_id) echo "ha" ;;
            log_level) echo "info" ;;

            # Two accounts — triggers multi-account TOML path
            "llu_accounts|length") echo "2" ;;
            "llu_accounts[0].name") echo "home" ;;
            "llu_accounts[0].email") echo "alice@example.com" ;;
            "llu_accounts[0].password") echo "alicepw" ;;
            "llu_accounts[0].region") echo "EU" ;;
            "llu_accounts[0].patient_id") echo "patient-1" ;;
            "llu_accounts[0].timezone") echo "Europe/Berlin" ;;
            "llu_accounts[0].version") echo "3.2.1" ;;
            "llu_accounts[1].name") echo "mobile" ;;
            "llu_accounts[1].email") echo "bob@example.com" ;;
            "llu_accounts[1].password") echo "bobpw" ;;
            "llu_accounts[1].region") echo "US" ;;
            "llu_accounts[1].patient_id") echo "" ;;
            "llu_accounts[1].timezone") echo "America/New_York" ;;
            "llu_accounts[1].version") echo "" ;;
            *) echo "mock: unexpected config '$1'" >&2; return 1 ;;
        esac
    }
    bashio::var.is_empty() { [ -z "$1" ]; }
    bashio::log.info() { echo "[mock-info] $*" >&2; }
    bashio::log.warning() { echo "[mock-warn] $*" >&2; }
    bashio::log.error() { echo "[mock-error] $*" >&2; }
    bashio::exit.nok() {
        echo "[mock-nok] $*" >&2
        exit 1
    }

    source /tmp/run-multi.sh
) > /tmp/multi-stdout.txt 2> /tmp/multi-stderr.txt || true  # exec will fail — fine

# Reached the exec marker?
if ! grep -q 'EXEC_CAPTURED' /tmp/multi-stderr.txt; then
    echo "FAIL: run.sh did not reach exec line" >&2
    echo "----- stderr -----" >&2
    cat /tmp/multi-stderr.txt >&2
    exit 1
fi

# TOML must have been captured.
if [ ! -f "${TOML_CAPTURE}" ]; then
    echo "FAIL: TOML was not captured (template not generated)" >&2
    exit 1
fi

fail=0

# --- Assert MQTT credentials (the critical bug from #21) ---
if ! grep -q 'username = "mosquitto"' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing correct MQTT username" >&2
    grep 'username' "${TOML_CAPTURE}" >&2
    fail=1
fi
if ! grep -q 'password = "mqttpw"' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing correct MQTT password" >&2
    grep 'password' "${TOML_CAPTURE}" >&2
    fail=1
fi

# --- Assert per_source flag ---
if ! grep -q 'per_source = true' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing per_source = true" >&2
    fail=1
fi

# --- Assert per-source sections ---
if ! grep -q '\[source\.sources\.home\]' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing [source.sources.home]" >&2
    fail=1
fi
if ! grep -q '\[source\.sources\.mobile\]' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing [source.sources.mobile]" >&2
    fail=1
fi

# --- Assert populated fields per account ---
if ! grep -q 'patient_id = "patient-1"' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing home patient_id" >&2
    fail=1
fi
if ! grep -q 'version = "3.2.1"' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML missing home version" >&2
    fail=1
fi

# Account "mobile" has no patient_id and no version — must not appear with
# empty values (they are conditionally emitted via [ -n "${ACCT_PATIENT}" ])
if grep -q 'patient_id = ""' "${TOML_CAPTURE}"; then
    echo "FAIL: TOML should omit empty optional fields" >&2
    fail=1
fi

# --- Assert log message confirms multi-account mode ---
if ! grep -q 'Multi-account mode' /tmp/multi-stderr.txt; then
    echo "FAIL: run.sh did not log multi-account mode" >&2
    fail=1
fi

# --- Check for TOML syntax errors (if basic parser available) ---
if command -v tomlq >/dev/null 2>&1; then
    if ! tomlq . "${TOML_CAPTURE}" >/dev/null 2>&1; then
        echo "FAIL: TOML syntax invalid" >&2
        fail=1
    fi
fi

if [ $fail -ne 0 ]; then
    echo "----- generated TOML -----" >&2
    cat "${TOML_CAPTURE}" >&2
    echo "----- stderr -----" >&2
    cat /tmp/multi-stderr.txt >&2
    exit 1
fi

echo "OK: multi-account TOML generation produces correct config"
