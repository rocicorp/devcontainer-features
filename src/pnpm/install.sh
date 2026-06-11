#!/usr/bin/env bash
set -euo pipefail

# Option (booleans arrive as the strings "true"/"false").
REMOVE_NPM="${REMOVENPM:-true}"

if ! command -v corepack >/dev/null 2>&1; then
  echo "ERROR: corepack not found. This feature needs a Node.js install (base image or node feature)." >&2
  exit 1
fi

echo "Enabling Corepack..."
corepack enable

# `corepack install` (pins pnpm from the workspace packageManager field) and the optional
# npm removal both have to run at postCreate, not here:
#   - the workspace isn't mounted during the build, so package.json isn't readable yet;
#   - npm must survive until other features (e.g. global npm installs) have run at build time.
# So we bake a hook script that the feature's postCreateCommand invokes.
HOOK_DIR=/usr/local/share/rocicorp-pnpm
HOOK="$HOOK_DIR/post-create.sh"
mkdir -p "$HOOK_DIR"

cat > "$HOOK" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
# Install the pnpm version pinned in the workspace's package.json (packageManager field).
corepack install 2>/dev/null || echo "pnpm feature: no packageManager field found; skipping 'corepack install'."
EOS

if [ "$REMOVE_NPM" = "true" ]; then
  cat >> "$HOOK" <<'EOS'
# Enforce pnpm: drop npm/npx so they can't be used by mistake.
sudo rm -rf /usr/local/bin/npm /usr/local/bin/npx /usr/local/lib/node_modules/npm 2>/dev/null || true
EOS
fi

chmod +x "$HOOK"
echo "Wrote postCreate hook to $HOOK (removeNpm=$REMOVE_NPM)."
