#!/usr/bin/env bash
#
# Smoke test: run run.sh under mocked bashio and assert it exports the
# expected GLUCO_HUB__* environment variables. Validates the ENV-name
# spelling — the single biggest risk surface in the wrapper.

set -euo pipefail

cd "$(dirname "$0")/.."

# Use a unique writable directory in place of /data so the test does
# not need root to create /data/state.
TEST_STATE_PARENT="$(mktemp -d -t ha-libre-glucose-mqtt-test.XXXXXX)"
trap 'rm -rf "${TEST_STATE_PARENT}"' EXIT

# Build a version of run.sh that:
#  1. drops the `#!/usr/bin/with-contenv bashio` shebang
#  2. retargets the hard-coded /data prefix to a writable temp dir
#  3. replaces the final `exec /usr/local/bin/gluco-hub run` with a
#     stderr marker so the script returns cleanly into the test harness.
sed -e '1d' \
    -e "s|/data/state|${TEST_STATE_PARENT}/state|g" \
    -e 's|^exec /usr/local/bin/gluco-hub run.*|echo "EXEC_CAPTURED" >\&2|' \
    ha-libre-glucose-mqtt/run.sh \
    > /tmp/run-modified.sh

# Run the mocked script in a subshell so `set -euo pipefail` inside
# run.sh does not leak into the assertion phase. Capture all the env
# vars run.sh exports (those starting with GLUCO_HUB__, GLUCO_HUB_, or
# RUST_LOG) plus stderr.
(
    # shellcheck source=tests/mock-bashio.sh
    source tests/mock-bashio.sh
    # shellcheck disable=SC1091
    source /tmp/run-modified.sh
    env | grep -E '^(GLUCO_HUB(__|_)|RUST_LOG=)' | sort
) > /tmp/captured-env.txt 2> /tmp/captured-stderr.txt

# Reached the exec marker?
if ! grep -q 'EXEC_CAPTURED' /tmp/captured-stderr.txt; then
    echo "FAIL: run.sh did not reach the gluco-hub exec line" >&2
    echo "----- stderr -----" >&2
    cat /tmp/captured-stderr.txt >&2
    exit 1
fi

# Expected env vars (must match exactly).
declare -A expected=(
    [GLUCO_HUB__SOURCE__LLU__EMAIL]="test@example.com"
    [GLUCO_HUB__SOURCE__LLU__PASSWORD]="testpw123"
    [GLUCO_HUB__SOURCE__LLU__REGION]="EU"
    [GLUCO_HUB__SOURCE__LLU__TIMEZONE]="Europe/Berlin"
    [GLUCO_HUB__POLLER__INTERVAL_SECS]="60"
    [GLUCO_HUB__HTTP__BIND]="0.0.0.0:8080"
    [GLUCO_HUB__SINK__MQTT__BROKER_HOST]="mock-mqtt.local"
    [GLUCO_HUB__SINK__MQTT__BROKER_PORT]="1883"
    [GLUCO_HUB__SINK__MQTT__CLIENT_ID]="gluco-hub-test"
    [GLUCO_HUB__SINK__MQTT__USERNAME]="mosquitto"
    [GLUCO_HUB__SINK__MQTT__PASSWORD]="mqttpw"
    [GLUCO_HUB__SINK__MQTT__TOPIC_PREFIX]="gluco-hub/test"
    [GLUCO_HUB__SINK__MQTT__TLS]="false"
    [GLUCO_HUB__SINK__MQTT__DISCOVERY_ENABLED]="true"
    [GLUCO_HUB__SINK__MQTT__DISCOVERY_PREFIX]="homeassistant"
    [GLUCO_HUB__STATE__DIR]="${TEST_STATE_PARENT}/state"
    [RUST_LOG]="info"
    [GLUCO_HUB_LOG_PRETTY]="1"
)

fail=0
for key in "${!expected[@]}"; do
    expected_val="${expected[$key]}"
    if ! grep -Fxq "${key}=${expected_val}" /tmp/captured-env.txt; then
        actual=$(grep "^${key}=" /tmp/captured-env.txt || echo "(unset)")
        echo "FAIL: ${key}" >&2
        echo "  expected: ${key}=${expected_val}" >&2
        echo "  got:      ${actual}" >&2
        fail=1
    fi
done

# Options that are empty in the mock must NOT show up in the exported
# env (run.sh guards them behind `bashio::var.is_empty` checks).
for key in GLUCO_HUB__SOURCE__LLU__PATIENT_ID GLUCO_HUB__SINK__MQTT__DEVICE_NAME; do
    if grep -q "^${key}=" /tmp/captured-env.txt; then
        echo "FAIL: ${key} was exported despite the option being empty" >&2
        fail=1
    fi
done

if [ $fail -ne 0 ]; then
    echo "----- full captured env -----" >&2
    cat /tmp/captured-env.txt >&2
    exit 1
fi

echo "OK: run.sh produces all expected env vars (${#expected[@]} checked)"
