#!/usr/bin/env bash
set -euo pipefail

chmod +x scripts/build-deb.sh

rm -f dist/*.deb || true
mkdir -p dist

for target in \
  ubuntu:amd64 \
  ubuntu:arm64 \
  debian:amd64 \
  debian:arm64
 do
  distro="${target%%:*}"
  arch="${target#*:}"
  echo "Building ${distro}/${arch}"
  TARGET_ARCH="$arch" DISTRO="$distro" OUTPUT_DIR="$GITHUB_WORKSPACE/workspace/dist" PODMAN_VERSION="$PODMAN_VERSION" PODMAN_SRC_DIR="$GITHUB_WORKSPACE/podman-src" ./scripts/build-deb.sh
 done
