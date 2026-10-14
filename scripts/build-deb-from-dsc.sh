#!/usr/bin/env bash
# Build binary .deb packages from a Debian .dsc URL or distro apt source.
set -euo pipefail

usage() {
  echo "Usage: $0 --dsc URL [--out DIR] [--podman-upstream VERSION]" >&2
  echo "   or: $0 --source PACKAGE [--out DIR]" >&2
  exit 1
}

DSC_URL=""
SOURCE_PKG=""
OUT_DIR="/artifacts"
PODMAN_UPSTREAM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dsc) DSC_URL="$2"; shift 2 ;;
    --source) SOURCE_PKG="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --podman-upstream) PODMAN_UPSTREAM="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -n "$DSC_URL" && -n "$SOURCE_PKG" ]] || [[ -z "$DSC_URL" && -z "$SOURCE_PKG" ]]; then
  usage
fi

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$script_path")" && pwd)"
# shellcheck source=install-build-deps.sh
source "${SCRIPT_DIR}/install-build-deps.sh"

export DEBIAN_FRONTEND=noninteractive
export DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)"
export DEBFULLNAME="${DEBFULLNAME:-Podman CI}"
export DEBEMAIL="${DEBEMAIL:-ci@localhost}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

if [[ -n "$SOURCE_PKG" ]]; then
  apt-get source "$SOURCE_PKG"
else
  if grep -qi ubuntu /etc/os-release 2>/dev/null; then
    # shellcheck source=setup-ubuntu-debian-build-deps.sh
    source "${SCRIPT_DIR}/setup-ubuntu-debian-build-deps.sh"
  fi
  dget -u "$DSC_URL"
fi

SRC_DIR=""
for candidate in */; do
  candidate="${candidate%/}"
  if [[ -d "${candidate}/debian" ]]; then
    SRC_DIR="$candidate"
    break
  fi
done

if [[ -z "$SRC_DIR" && -n "$DSC_URL" ]]; then
  DSC_FILE="$(basename "$DSC_URL")"
  dpkg-source -x --no-check "$DSC_FILE"
  for candidate in */; do
    candidate="${candidate%/}"
    if [[ -d "${candidate}/debian" ]]; then
      SRC_DIR="$candidate"
      break
    fi
  done
fi

if [[ -z "$SRC_DIR" ]]; then
  echo "Could not find unpacked source tree" >&2
  ls -la >&2
  exit 1
fi

cd "$SRC_DIR"

if [[ -n "$PODMAN_UPSTREAM" ]]; then
  echo "Bumping Podman upstream to ${PODMAN_UPSTREAM}"
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/podman-container-tools/podman/archive/v${PODMAN_UPSTREAM}.tar.gz" \
    | tar -xzf - -C "$tmp" --strip-components=1
  find . -mindepth 1 -maxdepth 1 ! -name debian -exec rm -rf {} +
  cp -a "$tmp"/. .
  rm -rf "$tmp"
  debchange --newversion "${PODMAN_UPSTREAM}+ds1-1~ci1" \
    -b "CI rebuild for upstream v${PODMAN_UPSTREAM}."
fi

install_build_deps

dpkg-buildpackage -us -uc -b

mkdir -p "$OUT_DIR"
shopt -s nullglob
cp -v ../*.deb "$OUT_DIR"/
