#!/usr/bin/env bash
# Enable deb-src lines for the current distro (Ubuntu or Debian).
set -euo pipefail

if [[ -f /etc/debian_version ]] && grep -qi ubuntu /etc/os-release 2>/dev/null; then
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  mirror="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu}"

  # Official Ubuntu Docker images often ship without universe; container packages live there.
  if ! grep -qE '[[:space:]]universe' /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null; then
    sed -i \
      -e "s/ ${codename} main restricted/ ${codename} main restricted universe multiverse/g" \
      -e "s/ ${codename}-updates main restricted/ ${codename}-updates main restricted universe multiverse/g" \
      -e "s/ ${codename}-security main restricted/ ${codename}-security main restricted universe multiverse/g" \
      /etc/apt/sources.list 2>/dev/null || true
  fi

  if ! grep -qE '^deb-src' /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    cat >>/etc/apt/sources.list <<EOF

deb-src ${mirror} ${codename} main restricted universe multiverse
deb-src ${mirror} ${codename}-updates main restricted universe multiverse
deb-src ${mirror} ${codename}-security main restricted universe multiverse
EOF
  fi
elif [[ -f /etc/debian_version ]]; then
  if ! grep -qE '^deb-src' /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources 2>/dev/null; then
    if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
      sed -i 's/Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
    else
      codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-bookworm}")"
      echo "deb-src http://deb.debian.org/debian ${codename} main" >>/etc/apt/sources.list
      echo "deb-src http://deb.debian.org/debian ${codename}-updates main" >>/etc/apt/sources.list
      echo "deb-src http://security.debian.org/debian-security ${codename}-security main" >>/etc/apt/sources.list
    fi
  fi
else
  echo "Unsupported OS: need Debian or Ubuntu" >&2
  exit 1
fi

apt-get update -qq
