#!/usr/bin/env bash
# Install built .deb packages in a clean Ubuntu/Debian container and run a smoke test.
set -euo pipefail

TEST_IMAGE="${1:?Usage: $0 TEST_IMAGE ARTIFACTS_DIR}"
ARTIFACTS_DIR="${2:?Usage: $0 TEST_IMAGE ARTIFACTS_DIR}"

if [[ ! -d "$ARTIFACTS_DIR" ]] || ! compgen -G "$ARTIFACTS_DIR/*.deb" >/dev/null; then
  echo "No .deb files found in ${ARTIFACTS_DIR}" >&2
  exit 1
fi

docker run --rm --privileged \
  -v "${ARTIFACTS_DIR}:/pkgs:ro" \
  "${TEST_IMAGE}" \
  bash -euxo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      ca-certificates curl crun conmon slirp4netns passt uidmap \
      iptables dbus
    # Install our packages and satisfy remaining deps from the distro when possible.
    apt-get install -y /pkgs/*.deb
    podman --version
    podman info 2>&1 | head -30
    mkdir -p /etc/containers
    printf "[registries.search]\nregistries = [\"docker.io\"]\n" >/etc/containers/registries.conf
    export CONTAINERS_STORAGE_DRIVER=vfs
    podman run --rm docker.io/library/alpine:3.20 echo "podman-smoke-test-ok"
  '

echo "Smoke test passed on ${TEST_IMAGE}"
