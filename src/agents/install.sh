#!/usr/bin/env bash
set -euo pipefail

# Feature options are passed in as uppercased env vars.
CODEX_VERSION="${CODEXVERSION:-latest}"

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required to install @openai/codex but was not found on PATH." >&2
  echo "       Add a Node.js feature (or use a node base image) before this feature." >&2
  exit 1
fi

echo "Installing @openai/codex@${CODEX_VERSION} ..."
npm install -g "@openai/codex@${CODEX_VERSION}"

echo "Done. Installed:"
codex --version || true
# Claude Code is provided by the dependsOn feature (anthropics/claude-code).
