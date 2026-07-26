#!/usr/bin/env bash
set -euo pipefail

repo="${PODMAN_REPOSITORY:-podman-container-tools/podman}"
input_version="${GITHUB_EVENT_INPUTS_VERSION:-}"

if [[ -n "$input_version" ]]; then
  version="$input_version"
else
  version="$(gh api repos/${repo}/releases/latest --jq '.tag_name')"
fi

if [[ -z "$version" ]]; then
  echo "Unable to resolve a Podman release tag." >&2
  exit 1
fi

if gh release view "$version" --repo "${GITHUB_REPOSITORY:-}" >/dev/null 2>&1; then
  should_build=false
else
  should_build=true
fi

echo "PODMAN_VERSION=$version" >> "$GITHUB_ENV"
echo "SHOULD_BUILD=$should_build" >> "$GITHUB_ENV"
echo "Building Podman version: $version"
