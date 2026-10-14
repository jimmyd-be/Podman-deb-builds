#!/usr/bin/env bash
# Flatten per-distro artifact directories into one folder with unique .deb names.
set -euo pipefail

SRC_ROOT="${1:?artifact root (contains podman-debs-* subdirs)}"
OUT_DIR="${2:?output directory}"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

shopt -s nullglob
for artifact_dir in "$SRC_ROOT"/podman-debs-*; do
  [[ -d "$artifact_dir" ]] || continue
  slug="${artifact_dir##*/podman-debs-}"
  for deb in "$artifact_dir"/*.deb; do
    name="$(basename "$deb")"
    # Renamed main package: podman-ubuntu-24.04-6.1.4_amd64.deb
    if [[ "$name" =~ ^podman-(ubuntu|debian)-.+_[a-z0-9]+\.deb$ ]]; then
      dest="$OUT_DIR/$name"
    else
      dest="$OUT_DIR/${slug}-${name}"
    fi
    cp -v "$deb" "$dest"
  done
done

count="$(find "$OUT_DIR" -maxdepth 1 -name '*.deb' | wc -l | tr -d ' ')"
if [[ "$count" == "0" ]]; then
  echo "No .deb files prepared under ${SRC_ROOT}" >&2
  exit 1
fi

echo "Prepared ${count} package(s) in ${OUT_DIR}"
