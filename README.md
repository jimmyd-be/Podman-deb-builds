# Podman-deb-builds

This repository builds unofficial Debian packages for Podman from the official upstream Podman source. These builds are not produced by the owners or maintainers of the Podman project, and they should not be considered official Podman releases.

The packages are built from the official Podman source tree and compiled with the following build tags:

- apparmor
- seccomp
- selinux
- systemd
- exclude_graphdriver_devicemapper

## What the workflow does

- Runs on a daily schedule and can also be triggered manually.
- Resolves the latest Podman release from the upstream containers/podman repository.
- Builds Debian packages for Ubuntu and Debian targets for amd64 and arm64.
- Publishes a GitHub release using the same version tag and the upstream release notes.
- Validates the generated .deb packages by installing them and checking that Podman runs.
