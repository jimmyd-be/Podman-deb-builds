#!/usr/bin/env bash
# Write Podman upstream release notes for VERSION to stdout (Markdown).
set -euo pipefail

VERSION="${1#v}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 VERSION" >&2
  exit 1
fi

api="https://api.github.com/repos/podman-container-tools/podman/releases/tags/v${VERSION}"
json="$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$api")"

body="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("body") or "")')"

if [[ -z "$body" ]]; then
  echo "No release notes found for Podman v${VERSION}" >&2
  exit 1
fi

cat <<EOF
## Podman v${VERSION} — .deb packages

Binary packages built for **Ubuntu 24.04**, **Ubuntu 26.04**, and **Debian trixie** from upstream [podman-container-tools/podman](https://github.com/podman-container-tools/podman) v${VERSION}.

### Upstream changelog

${body}
EOF
