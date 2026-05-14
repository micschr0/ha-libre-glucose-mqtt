# Minimal bashio stub for unit-testing run.sh outside the HA Supervisor.
#
# Each function below mirrors the real bashio API surface used by run.sh.
# Source this from a test harness BEFORE sourcing the (modified) run.sh.
# The mock returns canned values that the harness asserts against.

# shellcheck shell=bash

bashio::services.available() {
    case "$1" in
        mqtt) return 0 ;;
        *) return 1 ;;
    esac
}

bashio::services() {
    local svc="$1" key="$2"
    case "${svc}:${key}" in
        mqtt:host) echo "mock-mqtt.local" ;;
        mqtt:port) echo "1883" ;;
        mqtt:username) echo "mosquitto" ;;
        mqtt:password) echo "mqttpw" ;;
        *)
            echo "mock-bashio: unexpected services lookup ${svc}:${key}" >&2
            return 1
            ;;
    esac
}

bashio::config() {
    case "$1" in
        llu_email) echo "test@example.com" ;;
        llu_password) echo "testpw123" ;;
        llu_region) echo "EU" ;;
        llu_patient_id) echo "" ;;
        llu_timezone) echo "Europe/Berlin" ;;
        poll_interval_secs) echo "60" ;;
        device_name) echo "" ;;
        topic_prefix) echo "gluco-hub/test" ;;
        client_id) echo "gluco-hub-test" ;;
        log_level) echo "info" ;;
        *)
            echo "mock-bashio: unexpected config key '$1'" >&2
            return 1
            ;;
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
