#!/usr/bin/env bash
#
# Validate the EX-03 TOML block from libre-glucose/examples.md.
# Prefers real gluco-hub check-config validation; falls back to structural
# checks if the upstream image cannot be pulled.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

EXAMPLES_MD="libre-glucose/examples.md"
GLUCO_HUB_TAG="${GLUCO_HUB_TAG:-$(grep -oP 'GLUCO_HUB_TAG:\s*"?\K[^"\s]+' libre-glucose/build.yaml)}"
IMAGE="ghcr.io/micschr0/gluco-hub:${GLUCO_HUB_TAG}"

# Extract the first ```toml ... ``` block into a temp file.
# Use /tmp directly (world-accessible) so Docker volume mount can read it.
TMP_TOML="$(mktemp /tmp/ex03-validate.XXXXXX.toml)"
chmod 644 "${TMP_TOML}"
trap 'rm -f "${TMP_TOML}"' EXIT

python3 /dev/stdin "${EXAMPLES_MD}" "${TMP_TOML}" << 'PYEOF'
import re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    raw = f.read()
blocks = re.findall(r"^```toml\n(.*?)^```", raw, re.S | re.M)
if not blocks:
    print("ERROR: no toml block found in examples.md", file=sys.stderr)
    sys.exit(1)
with open(sys.argv[2], "w", encoding="utf-8") as out:
    out.write(blocks[0])
print(f"Extracted {len(blocks[0].splitlines())} lines of TOML")
PYEOF

# --- Structural checks (always run, mandatory) ---
echo ">> Structural validation"

python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1],'rb'))" "${TMP_TOML}" \
    || { echo "FAIL: TOML does not parse via tomllib"; exit 1; }

for required in "per_source = true" "[source.sources.alex]" "[source.sources.sam]" "broker_host"; do
    if ! grep -q "${required}" "${TMP_TOML}"; then
        echo "FAIL: TOML missing required content: ${required}"
        exit 1
    fi
done

if grep -qE '^\s*(^host|^port) = ' "${TMP_TOML}"; then
    echo "FAIL: TOML uses bare host/port keys — must use broker_host/broker_port"
    exit 1
fi

echo ">> Structural checks passed"

# --- Real validation via gluco-hub check-config (preferred) ---
echo ">> Attempting to pull ${IMAGE}"
if docker pull "${IMAGE}" >/dev/null 2>&1; then
    echo ">> Running gluco-hub check-config on extracted TOML"
    OUTPUT=$(docker run --rm \
        -v "${TMP_TOML}:/tmp/gluco-hub.toml:ro" \
        "${IMAGE}" check-config --config /tmp/gluco-hub.toml 2>&1 || true)
    echo "${OUTPUT}"
    if echo "${OUTPUT}" | grep -qi "configuration ok"; then
        echo "REAL_VALIDATION=check-config configuration ok"
        exit 0
    else
        echo "FAIL: gluco-hub check-config did not report 'configuration ok'"
        echo "Output was: ${OUTPUT}"
        exit 1
    fi
else
    echo "FALLBACK=structural (image unavailable)"
    exit 0
fi
