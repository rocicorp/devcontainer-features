#!/usr/bin/env bash
set -euo pipefail

# Feature options are passed in as uppercased env vars.
CODEX_VERSION="${CODEXVERSION:-latest}"
GH_TOKEN_OP_REF="${GHTOKENSECRETREF:-}"

# --- OpenAI Codex CLI ---------------------------------------------------------
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required to install @openai/codex but was not found on PATH." >&2
  echo "       Add a Node.js feature (or use a node base image) before this feature." >&2
  exit 1
fi

echo "Installing @openai/codex@${CODEX_VERSION} ..."
npm install -g "@openai/codex@${CODEX_VERSION}"
codex --version || true
# Claude Code is provided by the dependsOn feature (anthropics/claude-code).
# GitHub CLI is provided by the dependsOn feature (devcontainers/github-cli).

# --- 1Password CLI (op) -------------------------------------------------------
# Bundled so `gh` can authenticate from a short-lived token resolved out of
# 1Password at shell start, instead of persisting GitHub credentials on the host.
install_op() {
  if command -v op >/dev/null 2>&1; then
    echo "1Password CLI already installed: $(op --version)"
    return 0
  fi
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "WARNING: apt-get not found; skipping 1Password CLI install." >&2
    echo "         Install 'op' manually if you want gh-via-1Password auth." >&2
    return 0
  fi

  local arch keyring
  arch="$(dpkg --print-architecture)"
  keyring=/usr/share/keyrings/1password-archive-keyring.gpg
  export DEBIAN_FRONTEND=noninteractive

  echo "Installing the 1Password CLI ..."
  apt-get update
  apt-get install -y --no-install-recommends curl gnupg ca-certificates

  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | gpg --dearmor --yes --output "$keyring"
  echo "deb [arch=${arch} signed-by=${keyring}] https://downloads.1password.com/linux/debian/${arch} stable main" \
    > /etc/apt/sources.list.d/1password.list

  # debsig verification policy (per 1Password's official install docs).
  mkdir -p /etc/debsig/policies/AC2D62742012EA22/
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol \
    > /etc/debsig/policies/AC2D62742012EA22/1password.pol
  mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | gpg --dearmor --yes --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg

  apt-get update
  apt-get install -y 1password-cli
  op --version || true
}
install_op

# --- gh token injection via 1Password ----------------------------------------
# Drop a login-shell profile script that resolves GH_TOKEN from a 1Password
# secret reference (op://vault/item/field) fresh per shell. Requires `op` to be
# authenticated in the container (set OP_SERVICE_ACCOUNT_TOKEN). When no secret
# reference is configured, or op can't resolve it, this is a no-op and you can
# fall back to `gh auth login` or a GITHUB_TOKEN env var. Nothing is persisted
# on the host.
profile_script=/etc/profile.d/10-gh-op-token.sh
cat > "$profile_script" <<EOF
# Managed by the rocicorp 'agents' dev container feature — do not edit.
# Resolve a GitHub token for the gh CLI from 1Password, fresh per shell, so no
# GitHub credentials are persisted on the host.
GH_TOKEN_OP_REF="${GH_TOKEN_OP_REF}"
if [ -n "\${GH_TOKEN_OP_REF}" ] \\
   && command -v op >/dev/null 2>&1 \\
   && [ -z "\${GH_TOKEN:-}" ] && [ -z "\${GITHUB_TOKEN:-}" ]; then
  if _gh_tok="\$(op read "\${GH_TOKEN_OP_REF}" 2>/dev/null)"; then
    export GH_TOKEN="\${_gh_tok}"
  fi
  unset _gh_tok
fi
EOF
chmod 0644 "$profile_script"

echo "Done."
