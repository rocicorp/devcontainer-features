#!/usr/bin/env bash
set -euo pipefail

# Pulls in the dev container test library (check, reportResults).
source dev-container-features-test-lib

check "codex is installed" bash -c "codex --version"
check "claude is installed" bash -c "claude --version"
check "gh is installed" bash -c "gh --version"

reportResults
