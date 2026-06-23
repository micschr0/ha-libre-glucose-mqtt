#!/usr/bin/env python3
"""Validate all YAML fenced blocks in libre-glucose/examples.md.

Asserts:
- At least two ```yaml blocks exist.
- All ```yaml blocks parse with yaml.safe_load (no exceptions).
- EX-01 automation block: contains numeric_state (twice), below: 70, above: 180,
  sensor.gluco_hub_ha_glucose, notify.mobile_app reference; does NOT trigger on mgdl
  attribute.
- EX-02 gauge block: contains type: gauge, severity, sensor.gluco_hub_ha_glucose.
- Raw file text contains (configuration.md) cross-link.
"""
import re
import sys
from pathlib import Path

import yaml

# Resolve relative to the repo root (this file lives in tests/), so the
# validator works regardless of the caller's working directory.
EXAMPLES_MD = Path(__file__).resolve().parent.parent / "libre-glucose" / "examples.md"

with open(EXAMPLES_MD, encoding="utf-8") as f:
    raw = f.read()

# Extract all ```yaml ... ``` blocks
yaml_blocks = re.findall(r"```yaml\n(.*?)```", raw, re.S)

if len(yaml_blocks) < 2:
    print(f"FAIL: expected at least 2 yaml blocks, found {len(yaml_blocks)}")
    sys.exit(1)

# Parse every block
for i, block in enumerate(yaml_blocks):
    try:
        yaml.safe_load(block)
    except yaml.YAMLError as e:
        print(f"FAIL: yaml block {i + 1} failed to parse: {e}")
        sys.exit(1)

# Identify EX-01: the block containing "numeric_state"
ex01_blocks = [b for b in yaml_blocks if "numeric_state" in b]
if not ex01_blocks:
    print("FAIL: no yaml block contains 'numeric_state' (EX-01 automation missing)")
    sys.exit(1)
ex01 = ex01_blocks[0]

checks = [
    ("below: 70", ex01),
    ("above: 180", ex01),
    ("sensor.gluco_hub_ha_glucose", ex01),
    ("notify.mobile_app", ex01),
]
for needle, block in checks:
    if needle not in block:
        print(f"FAIL: EX-01 block missing expected content: {needle!r}")
        sys.exit(1)

if ex01.count("numeric_state") < 2:
    print("FAIL: EX-01 block should contain 'numeric_state' at least twice (two triggers)")
    sys.exit(1)

# Confirm EX-01 does NOT trigger on the mgdl attribute by checking trigger
# definitions (the attribute name should not appear in trigger context).
# We check that the trigger entities reference sensor state, not an attribute template.
# Simple guard: if "attribute: mgdl" appears, that would be wrong.
if "attribute: mgdl" in ex01:
    print("FAIL: EX-01 triggers on mgdl attribute — must trigger on sensor STATE")
    sys.exit(1)

# Identify EX-02: the block containing "type: gauge"
ex02_blocks = [b for b in yaml_blocks if "type: gauge" in b]
if not ex02_blocks:
    print("FAIL: no yaml block contains 'type: gauge' (EX-02 gauge card missing)")
    sys.exit(1)
ex02 = ex02_blocks[0]

for needle in ("severity", "sensor.gluco_hub_ha_glucose"):
    if needle not in ex02:
        print(f"FAIL: EX-02 gauge block missing: {needle!r}")
        sys.exit(1)

# Cross-link check
if "(configuration.md)" not in raw:
    print("FAIL: examples.md missing relative cross-link (configuration.md)")
    sys.exit(1)

print("OK: examples YAML valid")
