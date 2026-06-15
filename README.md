# Rocicorp dev container features

Shared [dev container Features](https://containers.dev/implementors/features/) so every
repo's containers come with the same baseline — without copy-pasting `post-create.sh`
across repos.

## `agents`

Installs the AI coding agents we standardize on:

- **OpenAI Codex CLI** (`@openai/codex`, version pinned via the `codexVersion` option)
- **Claude Code** (pulled in automatically via `dependsOn` on the official
  `ghcr.io/anthropics/devcontainer-features/claude-code` feature)
- **GitHub CLI** (`gh`, via `dependsOn` on the official
  `ghcr.io/devcontainers/features/github-cli` feature)
- **1Password CLI** (`op`, installed from 1Password's apt repo) — used to inject a
  GitHub token for `gh` without persisting credentials on the host

### Persistent Claude login

The feature mounts a named volume (`devcontainer-claude-config` at `/home/node/.claude`)
and sets `CLAUDE_CONFIG_DIR`, so the Claude session survives container **rebuilds** — you
log in once instead of after every rebuild. A `postCreateCommand` `chown`s the volume so
the `node` user can write to it.

> The volume is **shared across all repos** that use this feature (the Claude login is
> account-level, not repo-level), so logging in from one container carries over to the
> others. The mount path assumes the `node` remote user (the base image we standardize on).

### `gh` auth via 1Password (no host-side credentials)

Earlier versions persisted the `gh` login in a `devcontainer-gh-config` volume, which left
a long-lived GitHub token sitting on the host indefinitely. As of **v2.0.0** that volume is
gone. `gh` authenticates from a `GH_TOKEN`/`GITHUB_TOKEN` **environment variable** instead,
sourced from 1Password — nothing is written to the host.

The one fact that makes this non-obvious: **1Password's desktop-app integration (Touch ID
unlock) does _not_ work inside a container.** The `op` CLI's app integration talks to the
desktop app over a host-only socket the container can't reach. So the question is always
*"where does `op` actually run?"* — and that splits into two patterns.

#### Pattern A — Local dev container: resolve on the host, forward the token in (recommended)

Your **host** has the 1Password app + Touch ID. Resolve the GitHub token there and forward
just that token into the container. `gh` reads `GITHUB_TOKEN` directly, so you do **not**
set `ghTokenSecretRef` — the feature's in-container `op` step stays dormant.

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/agents:2": { "codexVersion": "0.139.0" }
},
// gh reads GITHUB_TOKEN; forward it from the host (resolved there via 1Password)
"remoteEnv": { "GITHUB_TOKEN": "${localEnv:GITHUB_TOKEN}" }
```

One-time **host** setup (the part that tripped us up — note the gotchas):

1. **Install the `op` CLI** — no package manager required. Download the macOS package or
   the standalone universal binary from <https://1password.com/downloads/command-line>,
   then enable **1Password app → Settings → Developer → Integrate with 1Password CLI**
   (Touch ID). Verify with `op vault list`.
2. **Export the token from your shell rc** — for zsh this is **`~/.zshrc`** (not `~/.zsh_rc`,
   which zsh never sources):
   ```bash
   export GITHUB_TOKEN="$(op read 'op://Employee/GitHub Personal Access Token/token')"
   ```
   Use the item's exact [secret reference][secret-ref] — in the 1Password app, right-click
   the field → **Copy Secret Reference**. Reload and check: `source ~/.zshrc` then
   `echo ${#GITHUB_TOKEN}` should be non-zero.
3. **Make the variable visible to the editor process.** `${localEnv:...}` is read from the
   editor's *process* environment, and **GUI/Dock/Spotlight launches do _not_ read
   `~/.zshrc`** — so a Dock-launched editor won't see `GITHUB_TOKEN`. Two ways to fix it:

   - **Launch from a terminal** (scopes the variable to that editor instance). Fully quit
     the editor first, then from a terminal where `echo ${#GITHUB_TOKEN}` is non-zero start
     it (`code`). Best when you open a folder/workspace from the CLI.
   - **`launchctl setenv`** (works with Dock/Spotlight launches — and with the no-checkout
     "Clone Repository in Container Volume" flow, where you never open a folder from the
     CLI):
     ```bash
     launchctl setenv GITHUB_TOKEN "$(op read 'op://Employee/GitHub Personal Access Token/token')"
     ```
     This puts the variable into your **GUI login session**, so anything launched afterward
     (including a Dock-launched editor) inherits it. Caveats:
     - **Relaunch** any already-running editor — it only picks up the value on a fresh launch.
     - **Not persistent** — `launchctl setenv` is cleared on logout/restart; re-run it each
       session, or automate it with a login LaunchAgent (below).
     - **Session-wide** — it's readable by *all* GUI apps in your login session, not just the
       editor. If you'd rather keep it scoped, use the terminal launch instead.

   Then build/reopen the container and check `gh auth status`.

   <details><summary>Optional: re-apply it automatically at login (LaunchAgent)</summary>

   Create `~/Library/LaunchAgents/com.rocicorp.github-token.plist`:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>Label</key><string>com.rocicorp.github-token</string>
     <key>ProgramArguments</key>
     <array>
       <string>/bin/sh</string>
       <string>-c</string>
       <string>launchctl setenv GITHUB_TOKEN "$(/usr/local/bin/op read 'op://Employee/GitHub Personal Access Token/token')"</string>
     </array>
     <key>RunAtLoad</key><true/>
   </dict>
   </plist>
   ```

   Load it with `launchctl load ~/Library/LaunchAgents/com.rocicorp.github-token.plist`.
   Caveat: it runs `op read` non-interactively at login, which only succeeds if 1Password can
   authorize without a prompt (e.g. the app is unlocked / CLI integration allows it) —
   otherwise just run the `launchctl setenv` line by hand each session.
   </details>

> Why this shape: only a short-lived *GitHub* token ever enters the container (not a
> credential that can read your whole vault), the secret still originates in 1Password, and
> nothing is persisted on a host volume. If `GITHUB_TOKEN` isn't set, `gh` is simply
> unauthenticated — a clean fallback; run `gh auth login` manually if you like.

#### Pattern B — Headless (Codespaces / CI): `op read` inside the container

When there's no desktop app to lean on, run `op` inside the container with a
[service-account token][service-account]. Set `ghTokenSecretRef` and forward
`OP_SERVICE_ACCOUNT_TOKEN`:

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/agents:2": {
    "ghTokenSecretRef": "op://Engineering/GitHub CLI/token"
  }
},
"remoteEnv": { "OP_SERVICE_ACCOUNT_TOKEN": "${localEnv:OP_SERVICE_ACCOUNT_TOKEN}" }
```

On each login shell, `/etc/profile.d/10-gh-op-token.sh` runs `op read "$ghTokenSecretRef"`
and exports the result as `GH_TOKEN`. If `ghTokenSecretRef` is empty, `op` is
unauthenticated, or the reference can't be resolved, the snippet is a no-op and you fall
back to `gh auth login` / a plain `GITHUB_TOKEN`. Scope the service account to **only** the
GitHub-token item, since that token lives in the container env.

[secret-ref]: https://developer.1password.com/docs/cli/secret-references/
[service-account]: https://developer.1password.com/docs/service-accounts/

### Usage

In any repo's `.devcontainer/devcontainer.json`:

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/agents:2": {
    // optional — override the pinned Codex version
    "codexVersion": "0.139.0"
  }
}
```

For `gh` authentication, add the `remoteEnv` (Pattern A) or `ghTokenSecretRef` + service
account (Pattern B) wiring from [`gh` auth via 1Password](#gh-auth-via-1password-no-host-side-credentials)
above — Pattern A is the right default for local dev containers.

This single line replaces the official `claude-code` and `github-cli` feature lines, the
inline `npm install -g @openai/codex`, **and** the `.claude` volume / `CLAUDE_CONFIG_DIR` /
`chown` wiring that otherwise lives in each repo's `devcontainer.json` + `post-create.sh`.

## `pnpm`

Sets up [pnpm](https://pnpm.io) via [Corepack](https://github.com/nodejs/corepack):

- Runs `corepack enable` (adds the `pnpm` shim) at build time.
- At `postCreate`, runs `corepack install` to pin the pnpm version from the workspace's
  `package.json` `packageManager` field.
- Removes the `npm`/`npx` binaries (after build-time installs have run) to enforce
  pnpm-only usage. This is the default; set `removeNpm: false` to keep npm available.

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/pnpm:1": {}
}
```

This replaces the corepack/pnpm/npm-removal block that otherwise lives in each repo's
`post-create.sh`. Combined with `agents`, a consumer repo's `devcontainer.json` needs no
lifecycle scripts at all.

## `docker`

Gives the container a working Docker daemon so tooling that shells out to Docker — most
notably [testcontainers](https://testcontainers.com) (used by the `zero-cache` Postgres
integration tests) — runs inside the dev container.

- Pulls in the official
  [`ghcr.io/devcontainers/features/docker-in-docker`](https://github.com/devcontainers/features/tree/main/src/docker-in-docker)
  feature via `dependsOn`, which installs the Docker engine, runs a daemon **inside** the
  container, and adds the remote user to the `docker` group (no `sudo` needed).
- Pins `"moby": false` so the upstream feature installs Docker CE from Docker's own apt
  repo instead of Microsoft's `moby-*` packages, which don't exist on Debian trixie
  (the base of current `javascript-node` images) and fail the build.
- Uses Docker-**in**-Docker rather than docker-outside-of-docker on purpose: testcontainers
  relies on bind mounts and container-to-container networking, both of which break under the
  host-socket approach (path translation) and aren't available in every environment
  (Codespaces, CI). A self-contained daemon "just works" everywhere.

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/docker:1": {}
}
```

This replaces a per-repo `docker-in-docker` feature line and centralizes the pinned version
alongside the other rocicorp features.

## Updating the feature versions everywhere

1. Bump `codexVersion` default (and/or the `dependsOn` claude-code pin) in
   `src/agents/devcontainer-feature.json`, raise the feature `version`, merge to `main`.
   The release workflow publishes a new tag to `ghcr.io`.
2. Consumer repos pick it up on next rebuild. To avoid hand-editing pins, enable
   **Dependabot** (`devcontainers` ecosystem) in each consumer repo — it opens PRs that
   bump the `devcontainer-lock.json` digests automatically.

## Publishing

`.github/workflows/release.yml` publishes all features under `src/` to
`ghcr.io/<owner>/devcontainer-features/<id>` on push to `main`
(via [`devcontainers/action`](https://github.com/devcontainers/action)).

> After the first publish, make the package public in the repo's
> **Packages** settings (or org package visibility) so consumer repos can pull it
> without auth.

## Testing locally

```bash
npm install -g @devcontainers/cli
devcontainer features test \
  --features agents \
  --base-image mcr.microsoft.com/devcontainers/javascript-node:24 \
  .
```
