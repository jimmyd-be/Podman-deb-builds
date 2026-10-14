#!/usr/bin/env bash
# Print latest Podman release version (without leading "v").
set -euo pipefail

api="https://api.github.com/repos/podman-container-tools/podman/releases/latest"
json="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api")"

tag="$(printf '%s\n' "$json" | grep '"tag_name"' | sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/')"

if [[ -z "$tag" ]]; then
  echo "Failed to resolve latest Podman release from ${api}" >&2
  exit 1
fi

printf '%s\n' "$tag"
