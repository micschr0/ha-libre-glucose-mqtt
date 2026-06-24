#!/usr/bin/env bash
#
# Smoke test: mdbook build succeeds and structural output checks pass.
#
# NOTE: This test is written for the Wave 0 scaffold. Assertions that depend
# on content pages (index, configuration, multi-account, etc.) and Docsify
# file removal will be RED until plans 12-02 and 12-03 land — that is the
# expected Wave-0 red->green progression.

set -euo pipefail

cd "$(dirname "$0")/.."

# --- Step 1: install admonish CSS (must run BEFORE mdbook build) ---
# Pitfall 2 (RESEARCH.md): mdbook-admonish install must precede mdbook build
# so that mdbook-admonish.css exists when the build processes the CSS list.
if ! mdbook-admonish install . 2>&1; then
    echo "FAIL: mdbook-admonish install exited non-zero" >&2
    exit 1
fi

# --- Step 2: build the book ---
if ! mdbook build 2>&1; then
    echo "FAIL: mdbook build exited non-zero" >&2
    exit 1
fi

fail=0

# --- Assert: all 8 doc pages exist as HTML (MIG-01) ---
# These will be missing until plan 12-02 provides the source .md files.
# mdBook auto-creates empty stub HTML for SUMMARY.md chapters whose source
# is missing, so build exits 0 even in Wave 0.
for page in index configuration multi-account clock-view status-api examples troubleshooting SECURITY; do
    if [ ! -f "book/${page}.html" ]; then
        echo "FAIL: book/${page}.html missing" >&2
        fail=1
    fi
done

# --- Assert: no raw Docsify callout syntax in built HTML (MIG-03) ---
# Will be RED until plan 12-02 converts all [!NOTE]/[!WARNING]/[!TIP] callouts.
raw_callouts=$(grep -r '\[!NOTE\]\|\[!WARNING\]\|\[!TIP\]' book/ 2>/dev/null | wc -l)
if [ "${raw_callouts}" -gt 0 ]; then
    echo "FAIL: ${raw_callouts} raw Docsify callout(s) found in built HTML" >&2
    fail=1
fi

# --- Assert: admonish CSS class present in book/ (MIG-04) ---
# Checks that mdbook-admonish preprocessor ran and emitted styled callout markup.
# Will be RED until plan 12-02 adds admonish fenced blocks to content pages.
if ! grep -rql "admonish" book/ 2>/dev/null; then
    echo "FAIL: admonish class not found anywhere in book/" >&2
    fail=1
fi

# --- Assert: HA-blue accent (#03A9F4) present in built custom.css (MIG-09) ---
if [ ! -f "book/custom.css" ] || ! grep -q '03A9F4' "book/custom.css"; then
    echo "FAIL: HA-blue accent (#03A9F4) not found in book/custom.css" >&2
    fail=1
fi

# --- Assert: Docsify entry point removed (MIG-11) ---
# Will be RED until plan 12-03 removes Docsify infrastructure files.
if [ -f "index.html" ]; then
    echo "FAIL: Docsify index.html still present at repo root (plan 12-03 removes this)" >&2
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "OK: mdbook build produced expected output (pages, callouts, accent, Docsify removal)"
