#!/usr/bin/env bash
set -euo pipefail

repo="${PODMAN_REPOSITORY:-podman-container-tools/podman}"
version="${PODMAN_VERSION:-}"

if [[ -z "$version" ]]; then
  echo "PODMAN_VERSION is required" >&2
  exit 1
fi

release_notes="$(gh api repos/${repo}/releases/tags/${version} --jq '.body' 2>/dev/null || true)"

if [[ -z "$release_notes" ]]; then
  release_notes="Automated Debian and Ubuntu package build for Podman ${version}."
fi

printf '%s\n' "$release_notes" > /tmp/release-notes.md
gh release create "$version" dist/*.deb \
  --repo "${GITHUB_REPOSITORY:-}" \
  --title "Podman ${version}" \
  --notes-file /tmp/release-notes.md
