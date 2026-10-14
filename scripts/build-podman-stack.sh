#!/usr/bin/env bash
# Build Podman and runtime companion .deb packages for installation on this distro.
set -euo pipefail

OUT_DIR="${OUT_DIR:-/artifacts}"
PODMAN_VERSION="${PODMAN_VERSION:-}"

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
# shellcheck source=enable-deb-src.sh
source "${SCRIPT_DIR}/enable-deb-src.sh"

if [[ -z "$PODMAN_VERSION" ]]; then
  PODMAN_VERSION="$("${SCRIPT_DIR}/latest-podman-version.sh")"
fi

echo "Target Podman upstream version: ${PODMAN_VERSION}"
mkdir -p "$OUT_DIR"

export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  devscripts dpkg-dev equivs quilt curl ca-certificates \
  build-essential fakeroot

# Packaging from Debian sid (close to current Podman 6.x).
DEBIAN_BASE="https://deb.debian.org/debian/pool/main"

build_one() {
  local letter="$1"
  local name="$2"
  local dsc="$3"
  local podman_upstream="${4:-}"
  echo "=== Building ${name} from ${dsc} ==="
  "${SCRIPT_DIR}/build-deb-from-dsc.sh" \
    --dsc "${DEBIAN_BASE}/${letter}/${name}/${dsc}" \
    --out "${OUT_DIR}" \
    ${podman_upstream:+--podman-upstream "$podman_upstream"}
}

# Companions first (versions from Debian sid pool as of 2026-03).
build_one g golang-github-containers-common golang-github-containers-common_0.69.1-1.dsc
build_one n netavark netavark_2.0.0-1.dsc
build_one a aardvark-dns aardvark-dns_1.17.1-3.dsc
build_one p podman podman_6.1.1+ds1-1.dsc "$PODMAN_VERSION"

if [[ -n "${DISTRO_SLUG:-}" ]]; then
  "${SCRIPT_DIR}/rename-podman-debs.sh" "$OUT_DIR" "$DISTRO_SLUG" "$PODMAN_VERSION"
fi

echo "Built packages:"
ls -la "$OUT_DIR"/*.deb
