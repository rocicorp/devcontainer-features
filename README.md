# Rocicorp dev container features

Shared [dev container Features](https://containers.dev/implementors/features/) so every
repo's containers come with the same baseline — without copy-pasting `post-create.sh`
across repos.

## `agents`

Installs the AI coding agents we standardize on:

- **OpenAI Codex CLI** (`@openai/codex`, version pinned via the `codexVersion` option)
- **Claude Code** (pulled in automatically via `dependsOn` on the official
  `ghcr.io/anthropics/devcontainer-features/claude-code` feature)

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

This single line replaces both the official `claude-code` feature line *and* the inline
`npm install -g @openai/codex` in `post-create.sh`.

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
