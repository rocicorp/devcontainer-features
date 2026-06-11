#!/usr/bin/env bash
set -euo pipefail

# The Docker engine itself is installed by the official Docker-in-Docker feature pulled in
# via `dependsOn` (it installs first and also adds the remote user to the `docker` group, so
# the daemon is reachable without sudo). This wrapper exists to give every rocicorp repo a
# single, centrally-pinned entry point for Docker — mirroring how `agents` wraps the official
# claude-code / github-cli features — and a place to hang any future testcontainers-specific
# defaults. There is nothing extra to install here.
echo "rocicorp/docker: Docker engine provided by the docker-in-docker dependency; no extra install steps."
