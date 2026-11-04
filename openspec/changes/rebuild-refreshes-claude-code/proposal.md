## Why

The Dockerfile installs `@anthropic-ai/claude-code@latest`, but Docker's layer cache keys on the instruction text, not on what npm would resolve. `claude-yolo rebuild` runs a plain `docker build`, so once that layer is cached every rebuild reuses the originally installed version and finishes in seconds. The existing requirement that a build installs the latest release is not met by `rebuild`.

## What Changes

- `claude-yolo rebuild` passes a fresh value for a new `CLAUDE_CODE_CACHE_BUST` build argument and `--pull`, so the npm install layer and everything after it is rebuilt and the base image is refreshed.
- The `Dockerfile` declares `ARG CLAUDE_CODE_CACHE_BUST` directly before the `npm install -g` step.
- Layers before the install step (system packages, Serena builder stage) stay cached.
- The automatic first-time build triggered by `yolo` and `run` is unchanged; a missing image has no cache to go stale.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sandbox/claude-code-updates`: adds a requirement that `claude-yolo rebuild` installs the latest Claude Code release even when earlier build layers are cached.

## Impact

- `Dockerfile`, `claude-yolo`, `test/claude-yolo.test.sh`, `README.md`.
- `rebuild` takes longer than before because the npm install layer and later layers always rerun.
