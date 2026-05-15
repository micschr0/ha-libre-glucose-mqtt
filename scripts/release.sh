#!/usr/bin/env bash
#
# Cut a CalVer release for ha-libre-glucose-mqtt.
#
# CalVer scheme: YYYY.MMDD.PATCH where MMDD = month*100 + day.
#   2026-05-15 → 2026.515.0
#   2026-12-01 → 2026.1201.0
#   2026-01-01 → 2026.101.0
# PATCH = 0 by default; bump with --patch for same-day re-releases.
#
# Modes:
#   (no args)     compute today's CalVer; update config.yaml; commit;
#                 tag `vX.Y.Z`; push
#   --dry-run     show what would happen, change nothing
#   --patch       bump PATCH for an existing same-day release
#   --rc          append `-rc.N` (next free N) for pre-releases
#
# The script is the single writer of `config.yaml`'s `version:` field.
# Renovate handles the Dockerfile/build.yaml GLUCO_HUB_TAG bumps when
# upstream gluco-hub-rs cuts a release — those two streams are
# independent (the addon may patch without upstream changing).

set -euo pipefail

MODE="default"
case "${1:-}" in
  --dry-run) MODE="dry" ;;
  --patch)   MODE="patch" ;;
  --rc)      MODE="rc" ;;
  "")        ;;
  *) echo "unknown arg: $1" >&2; exit 2 ;;
esac

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# Dry-run is for previewing — skip the working-tree + branch guards.
if [ "$MODE" != "dry" ]; then
  # Refuse to run on a dirty tree — release commits must be reproducible.
  if [ -n "$(git status --porcelain)" ]; then
    echo "Working tree is not clean. Commit or stash first." >&2
    git status --short >&2
    exit 1
  fi

  # Refuse to run off main — same constraint as gluco-hub-rs's
  # cargo-release flow (releases originate from main only).
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [ "$branch" != "main" ]; then
    echo "Releases must be cut from 'main' (current: $branch)." >&2
    exit 1
  fi
fi

# Compute today's CalVer base.
year=$(date -u +%Y)
month=$(date -u +%-m)
day=$(date -u +%-d)
minor=$((month * 100 + day))
patch=0

# Find the highest existing PATCH for today (final or RC) by scanning
# git tags so the script never re-uses a number.
prefix="v${year}.${minor}."
git fetch --tags --quiet
existing=$(git tag -l "${prefix}*" | sort -V | tail -1 || true)

case "$MODE" in
  patch)
    if [ -z "$existing" ]; then
      echo "No existing tag for ${year}.${minor}.x — use 'task release' for the first cut." >&2
      exit 1
    fi
    # Strip prefix and any -rc.N suffix to get the bare patch number.
    bare=${existing#"$prefix"}
    patch=${bare%%-*}
    patch=$((patch + 1))
    ;;
  rc)
    # next rc number for today's CalVer (patch 0)
    rc_n=1
    while git tag -l "${prefix}${patch}-rc.${rc_n}" | grep -q .; do
      rc_n=$((rc_n + 1))
    done
    version="${year}.${minor}.${patch}-rc.${rc_n}"
    ;;
  *)
    # Default / dry-run: PATCH = 0 if no same-day release exists,
    # else bump.
    if [ -n "$existing" ]; then
      bare=${existing#"$prefix"}
      bare=${bare%%-*}
      patch=$((bare + 1))
      echo "A release for ${year}.${minor}.x already exists ($existing) — bumping PATCH." >&2
    fi
    ;;
esac

if [ "$MODE" != "rc" ]; then
  version="${year}.${minor}.${patch}"
fi
tag="v${version}"

addon_config="libre-glucose/config.yaml"
current=$(grep -oP '^version:\s*"?\K[^"\s]+' "$addon_config" | head -1)

echo "Current version:  $current"
echo "Target version:   $version"
echo "Target tag:       $tag"

if [ "$MODE" = "dry" ]; then
  echo "[dry-run] No changes made."
  exit 0
fi

# Update config.yaml's version: field in place.
sed -i.bak -E "s|^version:\\s*\".*\"|version: \"${version}\"|" "$addon_config"
rm -f "${addon_config}.bak"

if ! grep -q "^version: \"${version}\"" "$addon_config"; then
  echo "Failed to update version in $addon_config — aborting." >&2
  exit 1
fi

git add "$addon_config"
# Skip the bump commit if config.yaml was already at the target
# version (typical when the user just bumped manually before running
# the script, or when version-in-file == version-from-CalVer-rule).
if git diff --cached --quiet; then
  echo "config.yaml already at ${version} — tagging current HEAD without a bump commit."
else
  git commit -m "chore: release ${tag}"
fi
git tag -a "$tag" -m "Release ${version}"

echo
echo "Tag ${tag} created locally. Pushing…"
git push origin HEAD "$tag"
echo "Done. .github/workflows/release.yml will now build + sign + push the image."
