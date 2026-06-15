#!/usr/bin/env bash
set -euo pipefail

# Pulls in the dev container test library (check, reportResults).
source dev-container-features-test-lib

check "codex is installed" bash -c "codex --version"
check "claude is installed" bash -c "claude --version"
check "gh is installed" bash -c "gh --version"
check "op is installed" bash -c "op --version"
check "gh-op-token profile script is present" bash -c "test -f /etc/profile.d/10-gh-op-token.sh"

reportResults
