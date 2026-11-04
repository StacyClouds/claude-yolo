## Why

The container ships the Aspire CLI, which includes an MCP server (`aspire agent mcp`) that lets an agent read the resources, logs and traces of a running Aspire app, the same data shown on the dashboard. Nothing registers it with Claude Code, so agents inside the container cannot talk to the dashboard. `aspire agent init` is the CLI's own way to register it, but it writes `.mcp.json`, skills and hooks into the mounted workspace, which the Dockerfile deliberately avoids.

## What Changes

- On every container start, the entrypoint registers `aspire` as a user-scope MCP server in `~/.claude.json`, running `aspire agent mcp`, the same way it already registers serena.
- Registration happens only when the Aspire CLI binary exists and is executable.
- No file is written into `/workspace`.

## Capabilities

### New Capabilities
- `aspire-mcp-runtime`: the Aspire MCP server is available to Claude Code in the container without touching the workspace.

### Modified Capabilities

## Impact

- `entrypoint.sh`: new registration block next to the serena one, with an override variable for the binary path (for tests).
- `test/entrypoint.test.sh`: new cases.
- Takes effect on the next container start; an already-running Claude Code session needs a restart to see the server.
