#!/usr/bin/env bash
# Rename built Podman .deb files to podman-{distro}-{tagversion}_{arch}.deb
set -euo pipefail

OUT_DIR="${1:?output directory}"
DISTRO_SLUG="${2:?distro slug, e.g. ubuntu-24.04, ubuntu-26.04, or debian-trixie}"
TAG_VERSION="${3:?Podman tag version, e.g. 6.1.4}"

ARCH="${4:-$(dpkg --print-architecture)}"

shopt -s nullglob
renamed=0

for deb in "$OUT_DIR"/podman_*.deb; do
  base="$(basename "$deb")"
  # Main podman package only (not podman-remote / podman-docker).
  [[ "$base" =~ ^podman_[0-9] ]] || continue
  new_name="podman-${DISTRO_SLUG}-${TAG_VERSION}_${ARCH}.deb"
  if [[ "$base" != "$new_name" ]]; then
    mv -v "$deb" "$OUT_DIR/$new_name"
    renamed=1
  fi
done

if [[ "$renamed" -eq 0 ]]; then
  echo "No podman_*.deb package found to rename in ${OUT_DIR}" >&2
  ls -la "$OUT_DIR" || true
  exit 1
fi
