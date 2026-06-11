#!/usr/bin/env bash
set -euo pipefail

source dev-container-features-test-lib

# corepack enable installs the pnpm shim onto PATH at build time.
check "pnpm shim on PATH" bash -c "command -v pnpm"
check "postCreate hook generated" bash -c "test -x /usr/local/share/rocicorp-pnpm/post-create.sh"
# removeNpm defaults to true, so the generated postCreate hook should drop npm/npx.
# (The removal itself runs at postCreate, after build-time installs.)
check "hook removes npm (removeNpm default true)" bash -c "grep -q 'rm -rf /usr/local/bin/npm' /usr/local/share/rocicorp-pnpm/post-create.sh"

reportResults
