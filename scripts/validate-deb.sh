#!/usr/bin/env bash
set -euo pipefail

package_path="${1:-}"
expected_version="${EXPECTED_VERSION:-}"

if [[ -z "$package_path" ]]; then
  echo "PACKAGE_PATH is required" >&2
  exit 1
fi

if [[ -z "$expected_version" ]]; then
  echo "EXPECTED_VERSION is required" >&2
  exit 1
fi

if [[ ! -f "$package_path" ]]; then
  echo "Package not found: $package_path" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt_cmd=(apt-get)
sudo_cmd=()
if command -v sudo >/dev/null 2>&1 && [[ "$(id -u)" -ne 0 ]]; then
  apt_cmd=(sudo apt-get)
  sudo_cmd=(sudo)
fi

"${apt_cmd[@]}" update
"${apt_cmd[@]}" install -y --no-install-recommends "$package_path"

"${sudo_cmd[@]}" mkdir -p /etc/containers
"${sudo_cmd[@]}" tee /etc/containers/registries.conf >/dev/null <<'EOF'
[registries.search]
registries = ['docker.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

podman_cmd=(podman)
if [[ ${#sudo_cmd[@]} -gt 0 ]]; then
  podman_cmd=(sudo podman)
fi

version_output="$(${podman_cmd[@]} --version)"
echo "$version_output"

expected_version="${expected_version#v}"
if [[ "$version_output" != *"$expected_version"* ]]; then
  echo "Installed Podman version '$version_output' does not match expected version '$expected_version'" >&2
  exit 1
fi

"${podman_cmd[@]}" info >/tmp/podman-info.txt 2>/tmp/podman-info.err || {
  echo "podman info failed" >&2
  cat /tmp/podman-info.err >&2
  exit 1
}

"${podman_cmd[@]}" run --rm --privileged hello-world >/tmp/podman-hello-world.txt 2>/tmp/podman-hello-world.err || {
  echo "podman hello-world failed" >&2
  cat /tmp/podman-hello-world.err >&2
  exit 1
}
