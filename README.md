# Rocicorp dev container features

Shared [dev container Features](https://containers.dev/implementors/features/) so every
repo's containers come with the same baseline — without copy-pasting `post-create.sh`
across repos.

## `agents`

Installs the AI coding agents we standardize on:

- **OpenAI Codex CLI** (`@openai/codex`, version pinned via the `codexVersion` option)
- **Claude Code** (pulled in automatically via `dependsOn` on the official
  `ghcr.io/anthropics/devcontainer-features/claude-code` feature)

> **v3.0.0** drops the bundled GitHub CLI (`gh`) and 1Password CLI (`op`), so the container no
> longer needs a GitHub token injected at shell start. If a repo still wants `gh`, add the
> official [`github-cli`](https://github.com/devcontainers/features/tree/main/src/github-cli)
> feature directly.

### Persistent Claude login

The feature mounts a named volume (`devcontainer-claude-config` at `/home/node/.claude`)
and sets `CLAUDE_CONFIG_DIR`, so the Claude session survives container **rebuilds** — you
log in once instead of after every rebuild. A `postCreateCommand` `chown`s the volume so
the `node` user can write to it.

> The volume is **shared across all repos** that use this feature (the Claude login is
> account-level, not repo-level), so logging in from one container carries over to the
> others. The mount path assumes the `node` remote user (the base image we standardize on).

### Usage

In any repo's `.devcontainer/devcontainer.json`:

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/agents:3": {
    // optional — override the pinned Codex version
    "codexVersion": "0.139.0"
  }
}
```

This single line replaces the official `claude-code` feature line, the
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
