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

build_companion() {
  local name="$1"
  echo "=== Building ${name} from distro apt source ==="
  "${SCRIPT_DIR}/build-deb-from-dsc.sh" \
    --source "$name" \
    --out "${OUT_DIR}"
}

# Use the trixie Netavark packaging on every target. Ubuntu's source package can
# require Rust crate packages that are not available from its repositories.
DEBIAN_BASE="https://deb.debian.org/debian/pool/main"
echo "=== Building netavark from Debian trixie packaging ==="
"${SCRIPT_DIR}/build-deb-from-dsc.sh" \
  --dsc "${DEBIAN_BASE}/n/netavark/netavark_1.14.0-2.dsc" \
  --out "${OUT_DIR}"

# Keep the remaining companions on the target distro's packaging.
build_companion golang-github-containers-common
build_companion aardvark-dns

# Podman: Debian 6.x packaging + latest upstream tarball. Its Go build-deps
# come from Debian sid on trixie; Ubuntu continues to use the trixie suite.
echo "=== Building podman from Debian packaging + upstream v${PODMAN_VERSION} ==="
"${SCRIPT_DIR}/build-deb-from-dsc.sh" \
  --dsc "${DEBIAN_BASE}/p/podman/podman_6.1.1+ds1-1.dsc" \
  --out "${OUT_DIR}" \
  --podman-upstream "$PODMAN_VERSION" \
  --debian-build-suite sid

if [[ -n "${DISTRO_SLUG:-}" ]]; then
  "${SCRIPT_DIR}/rename-podman-debs.sh" "$OUT_DIR" "$DISTRO_SLUG" "$PODMAN_VERSION"
fi

echo "Built packages:"
ls -la "$OUT_DIR"/*.deb
