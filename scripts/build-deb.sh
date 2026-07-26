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
PODMAN_SRC_DIR="${PODMAN_SRC_DIR:-}"

mkdir -p "$OUTPUT_DIR"

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

export DEBIAN_FRONTEND=noninteractive

if command -v apt-get >/dev/null 2>&1; then
  apt_cmd=(apt-get)
  if command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then
    apt_cmd=(sudo apt-get)
  fi

  "${apt_cmd[@]}" update
  packages=(
    build-essential
    bzip2
    ca-certificates
    curl
    dpkg-dev
    git
    golang-go
    libgpgme-dev
    libseccomp-dev
    libsystemd-dev
    make
    pkg-config
    gcc
    libc6-dev
  )

  case "$TARGET_ARCH" in
    arm64)
      packages+=(gcc-aarch64-linux-gnu libc6-dev-arm64-cross)
      ;;
    armhf)
      packages+=(gcc-arm-linux-gnueabihf libc6-dev-armhf-cross)
      ;;
    ppc64le)
      packages+=(gcc-powerpc64le-linux-gnu libc6-dev-ppc64el-cross)
      ;;
    s390x)
      packages+=(gcc-s390x-linux-gnu libc6-dev-s390x-cross)
      ;;
  esac

  "${apt_cmd[@]}" install -y --no-install-recommends "${packages[@]}"
fi

if [[ -n "$PODMAN_SRC_DIR" && -d "$PODMAN_SRC_DIR" ]]; then
  cp -a "$PODMAN_SRC_DIR"/. "$workdir/src"
else
  if [[ ! -d "$workdir/src" ]]; then
    git clone --depth 1 --branch "$VERSION" "$REPO_URL" "$workdir/src"
  fi
fi

mkdir -p "$workdir/src"
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
export CGO_ENABLED=1
export CGO_CFLAGS="-I/usr/include"

case "$TARGET_ARCH" in
  amd64)
    export CGO_LDFLAGS="-L/usr/lib/x86_64-linux-gnu"
    ;;
  arm64)
    export CC=aarch64-linux-gnu-gcc
    export CGO_LDFLAGS="-L/usr/lib/aarch64-linux-gnu"
    ;;
  armhf)
    export CC=arm-linux-gnueabihf-gcc
    export CGO_LDFLAGS="-L/usr/lib/arm-linux-gnueabihf"
    ;;
  ppc64le)
    export CC=powerpc64le-linux-gnu-gcc
    export CGO_LDFLAGS="-L/usr/lib/powerpc64le-linux-gnu"
    ;;
  s390x)
    export CC=s390x-linux-gnu-gcc
    export CGO_LDFLAGS="-L/usr/lib/s390x-linux-gnu"
    ;;
  *)
    echo "Unsupported architecture: $TARGET_ARCH" >&2
    exit 1
    ;;
esac

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
