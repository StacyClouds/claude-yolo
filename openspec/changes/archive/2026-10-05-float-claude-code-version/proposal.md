## Why

The image currently pins Claude Code to an exact version (`ARG CLAUDE_VERSION=2.1.258`) and disables its background auto-updater, so every build installs that same fixed release. Whoever builds the image gets a Claude Code that is already behind, with no way to pick up a newer release without hand-editing the pin first.

## What Changes

- **BREAKING**: Remove the `CLAUDE_VERSION` build argument and its exact-version pin.
- Install `@anthropic-ai/claude-code@latest` during the `npm install -g` build step, so every image build resolves whatever is newest on npm at build time.
- Keep `DISABLE_AUTOUPDATER=1` so the version installed at build time doesn't drift again from a background update while a container is running — build time is now the only point where the version changes.
- Update the surrounding Dockerfile comments that describe the pin-and-disable rationale to describe the float-at-build-and-disable-at-runtime rationale instead.

## Capabilities

### New Capabilities
- `sandbox/claude-code-updates`: the sandbox image always installs the latest available Claude Code release at build time, and never updates it again at runtime.

### Modified Capabilities
(none)

## Impact

- `Dockerfile`: the `ARG CLAUDE_VERSION=...` line, the `npm install -g` step, and the comment block above `ENV DISABLE_AUTOUPDATER=1`.
- Image builds are no longer reproducible with respect to the Claude Code version — two builds taken at different times can install different Claude Code releases.
