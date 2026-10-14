#!/usr/bin/env bash
# Build binary .deb packages from a Debian .dsc URL or distro apt source.
set -euo pipefail

usage() {
  echo "Usage: $0 --dsc URL [--out DIR] [--podman-upstream VERSION]" >&2
  echo "          [--debian-build-suite SUITE]" >&2
  echo "   or: $0 --source PACKAGE [--out DIR]" >&2
  exit 1
}

install_build_deps() {
  export DEBIAN_FRONTEND=noninteractive

  if mk-build-deps -i -r -t "apt-get -y --allow-downgrades" debian/control; then
    return 0
  fi

  echo "mk-build-deps failed; trying apt-get build-dep and dependency fixups" >&2

  shopt -s nullglob
  for dep_deb in ../*-build-deps_*.deb; do
    apt-get install -y "$dep_deb" || true
  done

  apt-get -fy install || true
  apt-get build-dep -y . || true
  apt-get -fy install || true

  if dpkg-checkbuilddeps 2>/dev/null; then
    return 0
  fi

  echo "Build dependencies are still unsatisfied:" >&2
  dpkg-checkbuilddeps >&2 || true
  return 1
}

setup_cross_distro_build_deps() {
  local suite=""
  if grep -qi ubuntu /etc/os-release 2>/dev/null; then
    suite="${DEBIAN_BUILD_SUITE:-trixie}"
  elif grep -qi debian /etc/os-release 2>/dev/null; then
    suite="$BUILD_DEPS_SUITE"
    if [[ -z "$suite" ]]; then
      return 0
    fi
  else
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive

  apt-get install -y --no-install-recommends debian-archive-keyring

  cat >/etc/apt/sources.list.d/debian-for-build-deps.sources <<EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: ${suite}
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

  if grep -qi ubuntu /etc/os-release 2>/dev/null; then
    cat >/etc/apt/preferences.d/00podman-build-prefs <<EOF
Package: *
Pin: release o=Ubuntu
Pin-Priority: 800

Package: *
Pin: release o=Debian
Pin-Priority: 100

Package: golang-* go-md2man dh-golang debhelper cargo rustc dh-cargo libstd-rust-* librust-*
Pin: release o=Debian
Pin-Priority: 850
EOF
  else
    cat >/etc/apt/preferences.d/00podman-build-prefs <<EOF

Package: *
Pin: release n=trixie
Pin-Priority: 800

Package: *
Pin: release n=sid
Pin-Priority: 100

Package: golang-*
Pin: release n=sid
Pin-Priority: 850
EOF
  fi

  apt-get update -qq
}

DSC_URL=""
SOURCE_PKG=""
OUT_DIR="/artifacts"
PODMAN_UPSTREAM=""
BUILD_DEPS_SUITE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dsc) DSC_URL="$2"; shift 2 ;;
    --source) SOURCE_PKG="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --podman-upstream) PODMAN_UPSTREAM="$2"; shift 2 ;;
    --debian-build-suite) BUILD_DEPS_SUITE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -n "$DSC_URL" && -n "$SOURCE_PKG" ]] || [[ -z "$DSC_URL" && -z "$SOURCE_PKG" ]]; then
  usage
fi

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
  setup_cross_distro_build_deps
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
