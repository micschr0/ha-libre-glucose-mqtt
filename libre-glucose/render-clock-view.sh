#!/usr/bin/env bash
# render-clock-view.sh
# Render a mock-data Clock View screenshot from clock.html using headless Chromium.
# Output: libre-glucose/_media/clock-view.png
#
# Usage: bash render-clock-view.sh
#   Reads clock.html from the same directory as this script (libre-glucose/).
#
# Requirements: /usr/local/bin/chromium (Chrome for Testing)
# No package installs performed; compression skipped if no compressor on PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script lives in libre-glucose/ — REPO_ROOT is one level up
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# clock.html is in the same directory as this script
CLOCK_HTML="$SCRIPT_DIR/clock.html"
MEDIA_DIR="$SCRIPT_DIR/_media"
OUTPUT_PNG="$MEDIA_DIR/clock-view.png"
CHROMIUM="${CHROMIUM:-/usr/local/bin/chromium}"

if [[ ! -f "$CLOCK_HTML" ]]; then
  echo "ERROR: clock.html not found at $CLOCK_HTML" >&2
  exit 1
fi

if [[ ! -x "$CHROMIUM" ]]; then
  echo "ERROR: chromium not found at $CHROMIUM" >&2
  exit 1
fi

# Create _media directory
mkdir -p "$MEDIA_DIR"

# Work in a temp directory, cleaned up on exit
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

WRAPPED_HTML="$TMPDIR/wrapped.html"
TMP_PNG="$TMPDIR/clock-view.png"

# Build a now-timestamp (Unix ms) for the mock reading
# Use python3 for reliable millisecond precision across platforms
NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))")

# Mock data stub script to inject before clock.html's own <script>
# This sets window.CLOCK_CONFIG and stubs fetch/EventSource so the display
# populates immediately with: 112 mg/dL, Flat trend, patient "Alex".
STUB_SCRIPT='<script>
(function() {
  // --- Mock config (matches what gluco-hub-rs would embed) ---
  window.CLOCK_CONFIG = {
    unit: "mgdl",
    lo: 70,
    hi: 180,
    patient: "Alex",
    pollMs: 60000
  };

  // --- Mock reading ---
  var NOW = '"$NOW_MS"';
  var MOCK_STATE = {
    mgdl: 112,
    trend: "Flat",
    ts: NOW,
    delta: 0,
    patient: "Alex"
  };

  // History: 20 flat-ish points over the last 20 minutes
  var MOCK_HISTORY = (function() {
    var pts = [];
    for (var i = 20; i >= 1; i--) {
      pts.push({ ts: NOW - i * 60000, mgdl: 110 + Math.round(Math.sin(i * 0.5) * 2) });
    }
    return pts;
  })();

  // --- Stub fetch ---
  var _realFetch = window.fetch;
  window.fetch = function(url, opts) {
    var u = String(url);
    if (u === "/clock/state" || u.indexOf("/clock/state") !== -1) {
      return Promise.resolve({
        ok: true,
        status: 200,
        json: function() { return Promise.resolve(MOCK_STATE); }
      });
    }
    if (u === "/clock/history" || u.indexOf("/clock/history") !== -1) {
      return Promise.resolve({
        ok: true,
        status: 200,
        json: function() { return Promise.resolve(MOCK_HISTORY); }
      });
    }
    // Pass through any other fetch (none expected in this context)
    if (typeof _realFetch === "function") return _realFetch.apply(this, arguments);
    return Promise.reject(new Error("fetch not available for: " + u));
  };

  // --- Stub EventSource (no-op — snapshot from /clock/state is enough) ---
  window.EventSource = function(url) {
    this.url = url;
    this.readyState = 1; // OPEN
    this.onopen = null;
    this.onerror = null;
    this.addEventListener = function() {};
    this.removeEventListener = function() {};
    this.close = function() { this.readyState = 2; };
    // Fire onerror after a delay so the page does not stay on "Connecting"
    // The /clock/state fetch will have already populated the display by then.
    var self = this;
    setTimeout(function() {
      // Do nothing — we want the state snapshot to remain, not trigger reconnect
    }, 5000);
  };
  window.EventSource.CONNECTING = 0;
  window.EventSource.OPEN = 1;
  window.EventSource.CLOSED = 2;
})();
</script>'

# Inject stub just before the first <script> tag in clock.html
# clock.html has exactly one <script> at the app logic section (line ~777)
python3 - <<PYEOF
import re, sys

with open("$CLOCK_HTML", "r", encoding="utf-8") as f:
    html = f.read()

stub = '''$STUB_SCRIPT'''

# Insert stub before the first <script> tag
modified = html.replace("<script>", stub + "\n  <script>", 1)

if modified == html:
    print("WARNING: <script> tag not found in clock.html — stub not injected", file=sys.stderr)
    sys.exit(1)

with open("$WRAPPED_HTML", "w", encoding="utf-8") as f:
    f.write(modified)

print("Wrapper HTML written to $WRAPPED_HTML")
PYEOF

FILE_URL="file://$WRAPPED_HTML?preset=phone"

echo "Rendering Clock View via headless Chromium..."
echo "  URL: $FILE_URL"
echo "  Viewport: 390x844 (phone)"
echo "  Output: $TMP_PNG"

"$CHROMIUM" \
  --headless \
  --no-sandbox \
  --disable-gpu \
  --hide-scrollbars \
  --force-device-scale-factor=2 \
  --window-size=390,844 \
  --virtual-time-budget=3000 \
  --screenshot="$TMP_PNG" \
  "$FILE_URL" \
  2>/dev/null

if [[ ! -s "$TMP_PNG" ]]; then
  echo "ERROR: chromium produced no output or an empty file at $TMP_PNG" >&2
  exit 1
fi

# Verify it is a PNG
if ! file "$TMP_PNG" | grep -qi "PNG image"; then
  echo "ERROR: output is not a valid PNG image" >&2
  file "$TMP_PNG" >&2
  exit 1
fi

# Move to destination
cp "$TMP_PNG" "$OUTPUT_PNG"
echo "PNG saved to $OUTPUT_PNG"
SIZE=$(wc -c < "$OUTPUT_PNG")
echo "File size: $SIZE bytes"

# Optional compression (skip if no compressor available)
if command -v oxipng &>/dev/null; then
  echo "Compressing with oxipng..."
  oxipng -o4 "$OUTPUT_PNG"
elif command -v pngcrush &>/dev/null; then
  echo "Compressing with pngcrush..."
  CRUSH_TMP="$TMPDIR/crushed.png"
  pngcrush "$OUTPUT_PNG" "$CRUSH_TMP" && mv "$CRUSH_TMP" "$OUTPUT_PNG"
elif command -v optipng &>/dev/null; then
  echo "Compressing with optipng..."
  optipng "$OUTPUT_PNG"
elif command -v pngquant &>/dev/null; then
  echo "Compressing with pngquant..."
  pngquant --force --output "$OUTPUT_PNG" "$OUTPUT_PNG"
else
  echo "No PNG compressor found (oxipng/pngcrush/optipng/pngquant) — skipping compression."
fi

FINAL_SIZE=$(wc -c < "$OUTPUT_PNG")
echo "Done. Final size: $FINAL_SIZE bytes"
echo "Output: $OUTPUT_PNG"
