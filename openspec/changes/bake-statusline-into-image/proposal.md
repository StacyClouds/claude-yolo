## Why

The status line only appears inside a sandbox container when the host's `~/.claude` already contains `statusline-command.sh` and a `statusLine` entry in its `settings.json`. A host without those (for example, a second machine) gets a container with no status line, and the script exists nowhere in this repository.

## What Changes

- Add `statusline-command.sh` (Linux/bash only) to the repository root.
- The image build bakes the script into a location outside `/home/node`, alongside the other baked fallback content.
- Container start copies the baked script into `~/.claude/` when the host did not provide one.
- Container start sets `statusLine` in the container's `settings.json` when that file does not already define one.
- `.dockerignore` allowlists the new file so the build context includes it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sandbox/host-claude-config`: adds a requirement that a default status line is available in every container, with the host's own status line script and `statusLine` setting taking precedence when present.

## Impact

- `statusline-command.sh` (new), `Dockerfile`, `.dockerignore`, `entrypoint.sh`.
- `test/` gains tests for the entrypoint behaviour.
- Requires `claude-yolo rebuild` to take effect on an existing machine.
- No change for hosts that already provide both the script and the `statusLine` setting.
