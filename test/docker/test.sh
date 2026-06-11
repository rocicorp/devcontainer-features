#!/usr/bin/env bash
set -euo pipefail

# Pulls in the dev container test library (check, reportResults).
source dev-container-features-test-lib

check "docker client on PATH" bash -c "command -v docker"
check "docker daemon reachable" bash -c "docker ps"
# testcontainers shells out to `docker run`; make sure the daemon can actually start a container.
check "can run a container" bash -c "docker run --rm hello-world"

reportResults
