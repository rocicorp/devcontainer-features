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

### Persistent `gh` login

The feature mounts a named volume (`devcontainer-gh-config`) at
`/home/node/.config/gh`, so a `gh auth login` survives container **rebuilds** — you log
in once instead of after every rebuild. A `postCreateCommand` `chown`s the volume so the
`node` user can write to it.

> The volume is **shared across all repos** that use this feature (gh auth is account-level,
> not repo-level), so logging in from one container carries over to the others. The mount
> path assumes the `node` remote user (the base image we standardize on).

### Usage

In any repo's `.devcontainer/devcontainer.json`:

```jsonc
"features": {
  "ghcr.io/rocicorp/devcontainer-features/agents:1": {
    // optional — override the pinned Codex version
    "codexVersion": "0.139.0"
  }
}
```

This single line replaces the official `claude-code` and `github-cli` feature lines *and*
the inline `npm install -g @openai/codex` in `post-create.sh`.

### Updating the agent versions everywhere

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
