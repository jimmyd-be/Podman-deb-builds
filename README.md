# Podman-deb-builds

This repository contains a GitHub Actions workflow that checks for new Podman releases once per day, builds Debian packages for Ubuntu and Debian targets, and publishes a matching GitHub release with the generated .deb artifacts.

## What the workflow does

- Runs on a daily schedule and can also be triggered manually.
- Resolves the latest Podman release from the upstream containers/podman repository.
- Builds Debian packages for Ubuntu and Debian targets across supported architectures.
- Publishes a GitHub release using the same version tag and the upstream release notes.

## Files

- [.github/workflows/podman-release.yml](.github/workflows/podman-release.yml)
- [scripts/build-deb.sh](scripts/build-deb.sh)
