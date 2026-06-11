#!/usr/bin/env bash
set -euo pipefail

source dev-container-features-test-lib

# corepack enable installs the pnpm shim onto PATH at build time.
check "pnpm shim on PATH" bash -c "command -v pnpm"
check "postCreate hook generated" bash -c "test -x /usr/local/share/rocicorp-pnpm/post-create.sh"
# Default removeNpm=false, so npm should still be present.
check "npm still present (removeNpm default false)" bash -c "command -v npm"

reportResults
