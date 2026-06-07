#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
#
# Entrypoint for libre-glucose. Reads app options from
# /data/options.json (via bashio::config) and the MQTT service info
# provided by HA Supervisor (via bashio::services), then maps everything
# onto the GLUCO_HUB__<SECTION>__<KEY> environment variables that
# gluco-hub-rs already understands. No TOML file is written — gluco-hub's
# config loader falls back to ENV when no -c file is given.

set -euo pipefail

# ---------------------------------------------------------------------------
# MQTT service hand-off
# ---------------------------------------------------------------------------
if ! bashio::services.available 'mqtt'; then
    bashio::exit.nok \
        "No MQTT service available. Install the official Mosquitto broker add-on and configure the MQTT integration in Home Assistant first."
fi

MQTT_HOST="$(bashio::services 'mqtt' 'host')"
MQTT_PORT="$(bashio::services 'mqtt' 'port')"
MQTT_USERNAME="$(bashio::services 'mqtt' 'username')"
MQTT_PASSWORD="$(bashio::services 'mqtt' 'password')"

bashio::log.info "MQTT service: ${MQTT_HOST}:${MQTT_PORT} (user=${MQTT_USERNAME})"

# ---------------------------------------------------------------------------
# Add-on options → GLUCO_HUB__* env vars
# ---------------------------------------------------------------------------
LLU_EMAIL="$(bashio::config 'llu_email')"
LLU_PASSWORD="$(bashio::config 'llu_password')"
LLU_REGION="$(bashio::config 'llu_region')"
LLU_PATIENT_ID="$(bashio::config 'llu_patient_id')"
LLU_TIMEZONE="$(bashio::config 'llu_timezone')"
LLU_VERSION="$(bashio::config 'llu_version')"

POLL_INTERVAL_SECS="$(bashio::config 'poll_interval_secs')"
DEVICE_NAME="$(bashio::config 'device_name')"
GLUCOSE_UNIT="$(bashio::config 'glucose_unit')"
TOPIC_PREFIX="$(bashio::config 'topic_prefix')"
CLIENT_ID="$(bashio::config 'client_id')"
LOG_LEVEL="$(bashio::config 'log_level')"

if bashio::var.is_empty "${LLU_EMAIL}"; then
    bashio::exit.nok "Option 'llu_email' is required — configure it in the add-on UI."
fi
if bashio::var.is_empty "${LLU_PASSWORD}"; then
    bashio::exit.nok "Option 'llu_password' is required — configure it in the add-on UI."
fi

# Source — LibreLink Up
export GLUCO_HUB__SOURCE__LLU__EMAIL="${LLU_EMAIL}"
export GLUCO_HUB__SOURCE__LLU__PASSWORD="${LLU_PASSWORD}"
export GLUCO_HUB__SOURCE__LLU__REGION="${LLU_REGION}"
export GLUCO_HUB__SOURCE__LLU__TIMEZONE="${LLU_TIMEZONE}"
if ! bashio::var.is_empty "${LLU_VERSION}"; then
    export GLUCO_HUB__SOURCE__LLU__VERSION="${LLU_VERSION}"
fi
if ! bashio::var.is_empty "${LLU_PATIENT_ID}"; then
    export GLUCO_HUB__SOURCE__LLU__PATIENT_ID="${LLU_PATIENT_ID}"
fi

# Poller
export GLUCO_HUB__POLLER__INTERVAL_SECS="${POLL_INTERVAL_SECS}"

# HTTP API binds to 0.0.0.0:8080. The Supervisor Ingress proxy forwards
# authenticated HA-session requests to this port (config.yaml: ingress_port: 8080).
# The Docker HEALTHCHECK probes it directly. Port 8080 is not exposed to
# the host — only reachable via the Supervisor proxy or within the hassio
# bridge network.
export GLUCO_HUB__HTTP__BIND="0.0.0.0:8080"

# Sink — MQTT (Mosquitto add-on internal, plaintext, with HA discovery)
export GLUCO_HUB__SINK__MQTT__BROKER_HOST="${MQTT_HOST}"
export GLUCO_HUB__SINK__MQTT__BROKER_PORT="${MQTT_PORT}"
export GLUCO_HUB__SINK__MQTT__CLIENT_ID="${CLIENT_ID}"
export GLUCO_HUB__SINK__MQTT__USERNAME="${MQTT_USERNAME}"
export GLUCO_HUB__SINK__MQTT__PASSWORD="${MQTT_PASSWORD}"
export GLUCO_HUB__SINK__MQTT__TOPIC_PREFIX="${TOPIC_PREFIX}"
export GLUCO_HUB__SINK__MQTT__TLS="false"
export GLUCO_HUB__SINK__MQTT__DISCOVERY_ENABLED="true"
export GLUCO_HUB__SINK__MQTT__DISCOVERY_PREFIX="homeassistant"
export GLUCO_HUB__SINK__MQTT__DISCOVERY_UNIT="${GLUCOSE_UNIT}"
if ! bashio::var.is_empty "${DEVICE_NAME}"; then
    export GLUCO_HUB__SINK__MQTT__DEVICE_NAME="${DEVICE_NAME}"
fi

# Persistent state (DLQ) — survives add-on updates because /data is
# mapped via `map: data:rw` in config.yaml.
export GLUCO_HUB__STATE__DIR="/data/state"
mkdir -p /data/state

# Tracing
export RUST_LOG="${LOG_LEVEL}"
# Pretty logs in the HA add-on log viewer (it doesn't parse JSON).
export GLUCO_HUB_LOG_PRETTY="1"

# Schema fingerprint — log expected LLU JSON field names so operators can detect
# API changes by comparing fingerprints across versions.
bashio::log.info "LLU schema fingerprint: ValueInMgPerDl, ValueInMmolPerL, TrendArrow, Timestamp, PatientId"

ACCOUNT_COUNT=$(bashio::config 'llu_accounts|length' 2>/dev/null || echo "0")
if [ "${ACCOUNT_COUNT}" -gt 0 ]; then
    bashio::log.info "Multi-account mode: ${ACCOUNT_COUNT} source(s) — generating TOML config"

    cat > /tmp/gluco-hub.toml <<TOML
[poller]
interval_secs = ${POLL_INTERVAL_SECS}

[http]
bind = "0.0.0.0:8080"

[state]
dir = "/data/state"

[sink.mqtt]
host = "${MQTT_HOST}"
port = ${MQTT_PORT}
username = "${MQTT_USER}"
password = "${MQTT_PW}"
topic_prefix = "${TOPIC_PREFIX}"
client_id = "ha"
discovery_enabled = true
per_source = true
TOML

    for i in $(seq 0 $((ACCOUNT_COUNT - 1))); do
        ACCT_NAME=$(bashio::config "llu_accounts[${i}].name")
        ACCT_EMAIL=$(bashio::config "llu_accounts[${i}].email")
        ACCT_PASSWORD=$(bashio::config "llu_accounts[${i}].password")
        ACCT_REGION=$(bashio::config "llu_accounts[${i}].region")
        ACCT_PATIENT=$(bashio::config "llu_accounts[${i}].patient_id")
        ACCT_TZ=$(bashio::config "llu_accounts[${i}].timezone")
        printf '\n[source.sources.%s]\n' "${ACCT_NAME}" >> /tmp/gluco-hub.toml
        printf 'email = "%s"\n' "${ACCT_EMAIL}" >> /tmp/gluco-hub.toml
        printf 'password = "%s"\n' "${ACCT_PASSWORD}" >> /tmp/gluco-hub.toml
        printf 'region = "%s"\n' "${ACCT_REGION}" >> /tmp/gluco-hub.toml
        ACCT_VER=$(bashio::config "llu_accounts[${i}].version")
        [ -n "${ACCT_PATIENT}" ] && printf 'patient_id = "%s"\n' "${ACCT_PATIENT}" >> /tmp/gluco-hub.toml
        [ -n "${ACCT_TZ}" ] && printf 'timezone = "%s"\n' "${ACCT_TZ}" >> /tmp/gluco-hub.toml
        [ -n "${ACCT_VER}" ] && printf 'version = "%s"\n' "${ACCT_VER}" >> /tmp/gluco-hub.toml
    done

    bashio::log.info "Starting gluco-hub (multi-account)..."
    exec /usr/local/bin/gluco-hub --config /tmp/gluco-hub.toml run
fi

bashio::log.info "Starting gluco-hub (single-account)..."
exec /usr/local/bin/gluco-hub run
