#!/usr/bin/env bash
# Build binary .deb packages from a Debian .dsc URL (optionally bump Podman upstream).
set -euo pipefail

usage() {
  echo "Usage: $0 --dsc URL [--out DIR] [--podman-upstream VERSION]" >&2
  exit 1
}

DSC_URL=""
OUT_DIR="/artifacts"
PODMAN_UPSTREAM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dsc) DSC_URL="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --podman-upstream) PODMAN_UPSTREAM="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

[[ -n "$DSC_URL" ]] || usage

export DEBIAN_FRONTEND=noninteractive
export DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)"
export DEBFULLNAME="${DEBFULLNAME:-Podman CI}"
export DEBEMAIL="${DEBEMAIL:-ci@localhost}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

# -u: allow downloading Debian sources on Ubuntu; dget unpacks by default.
dget -u "$DSC_URL"

SRC_DIR="$(find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' -print -quit)"
if [[ -z "$SRC_DIR" || ! -d "${SRC_DIR}/debian" ]]; then
  DSC_FILE="$(basename "$DSC_URL")"
  dpkg-source -x --no-check "$DSC_FILE"
  SRC_DIR="$(find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' -print -quit)"
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

if ! mk-build-deps -i -r -t "apt-get -y" debian/control; then
  apt-get build-dep -y . || true
  mk-build-deps -i -r -t "apt-get -y" debian/control
fi

dpkg-buildpackage -us -uc -b

mkdir -p "$OUT_DIR"
shopt -s nullglob
cp -v ../*.deb "$OUT_DIR"/
