#!/usr/bin/env bash
#
# Smoke test: feed the GLUCO_HUB__* env vars our run.sh would export
# into `gluco-hub check-config` and confirm the binary accepts them.
# This catches semantic mismatches between our env names and the real
# field names in gluco-hub/src/config.rs (which a pure-bash unit test
# cannot see).
#
# Requires the upstream image to be available on the runner:
#   ghcr.io/micschr0/gluco-hub:${GLUCO_HUB_TAG}

set -euo pipefail

GLUCO_HUB_TAG="${GLUCO_HUB_TAG:-2026.514.0}"
IMAGE="ghcr.io/micschr0/gluco-hub:${GLUCO_HUB_TAG}"

echo ">> Pulling ${IMAGE}"
docker pull "${IMAGE}" >/dev/null

echo ">> Running gluco-hub check-config with mocked env"
docker run --rm \
    -e GLUCO_HUB__SOURCE__LLU__EMAIL=test@example.com \
    -e GLUCO_HUB__SOURCE__LLU__PASSWORD=testpw \
    -e GLUCO_HUB__SOURCE__LLU__REGION=EU \
    -e GLUCO_HUB__SOURCE__LLU__TIMEZONE=Europe/Berlin \
    -e GLUCO_HUB__POLLER__INTERVAL_SECS=60 \
    -e GLUCO_HUB__HTTP__BIND=0.0.0.0:8080 \
    -e GLUCO_HUB__SINK__MQTT__BROKER_HOST=mqtt.local \
    -e GLUCO_HUB__SINK__MQTT__BROKER_PORT=1883 \
    -e GLUCO_HUB__SINK__MQTT__CLIENT_ID=gluco-hub-test \
    -e GLUCO_HUB__SINK__MQTT__USERNAME=user \
    -e GLUCO_HUB__SINK__MQTT__PASSWORD=pw \
    -e GLUCO_HUB__SINK__MQTT__TOPIC_PREFIX=gluco-hub/test \
    -e GLUCO_HUB__SINK__MQTT__TLS=false \
    -e GLUCO_HUB__SINK__MQTT__DISCOVERY_ENABLED=true \
    -e GLUCO_HUB__SINK__MQTT__DISCOVERY_PREFIX=homeassistant \
    -e GLUCO_HUB__STATE__DIR=/tmp/state \
    -e RUST_LOG=info \
    "${IMAGE}" check-config

echo "OK: gluco-hub accepted the env-only configuration"
