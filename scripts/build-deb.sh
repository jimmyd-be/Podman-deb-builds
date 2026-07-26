#!/usr/bin/env bash
set -euo pipefail

VERSION="${PODMAN_VERSION:-}"
if [[ -z "$VERSION" ]]; then
  echo "PODMAN_VERSION is required" >&2
  exit 1
fi

TARGET_ARCH="${TARGET_ARCH:-amd64}"
DISTRO="${DISTRO:-ubuntu}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
REPO_URL="${PODMAN_REPO_URL:-https://github.com/containers/podman.git}"

mkdir -p "$OUTPUT_DIR"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    dpkg-dev \
    git \
    golang-go \
    make \
    pkg-config
fi

if [[ ! -d "$workdir/src" ]]; then
  git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$workdir/src"
fi

cd "$workdir/src"

case "$TARGET_ARCH" in
  amd64)
    export GOARCH=amd64
    ;;
  arm64)
    export GOARCH=arm64
    ;;
  armhf)
    export GOARCH=arm
    export GOARM=7
    ;;
  ppc64le)
    export GOARCH=ppc64le
    ;;
  s390x)
    export GOARCH=s390x
    ;;
  *)
    echo "Unsupported architecture: $TARGET_ARCH" >&2
    exit 1
    ;;
esac

export GOOS=linux
export CGO_ENABLED=0

make podman

pkg_dir="$workdir/pkg"
mkdir -p "$pkg_dir/DEBIAN" "$pkg_dir/usr/bin"
install -m 0755 bin/podman "$pkg_dir/usr/bin/podman"

package_arch="$TARGET_ARCH"
case "$TARGET_ARCH" in
  armhf)
    package_arch="armhf"
    ;;
  amd64)
    package_arch="amd64"
    ;;
  arm64)
    package_arch="arm64"
    ;;
  ppc64le)
    package_arch="ppc64le"
    ;;
  s390x)
    package_arch="s390x"
    ;;
esac

cat > "$pkg_dir/DEBIAN/control" <<EOF
Package: podman
Version: ${VERSION#v}
Section: utils
Priority: optional
Architecture: ${package_arch}
Maintainer: GitHub Actions <actions@github.com>
Description: Podman container runtime
 Podman is a daemonless container engine for developing, running, and
 managing OCI containers on Linux systems.
EOF

dpkg-deb --build "$pkg_dir" "$OUTPUT_DIR/podman_${VERSION#v}_${package_arch}.deb"

echo "Built $OUTPUT_DIR/podman_${VERSION#v}_${package_arch}.deb"
