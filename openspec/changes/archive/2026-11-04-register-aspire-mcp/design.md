## Context

`entrypoint.sh` already registers serena by rewriting `mcpServers.serena` in `~/.claude.json` with `jq` on every start, guarded by an executable check on a path that tests can override (`CLAUDE_YOLO_SERENA_BIN`). The Aspire CLI is installed at `/opt/aspire-cli` and symlinked to `/usr/local/bin/aspire`. `aspire agent mcp` finds running Aspire apps on its own, so it needs no arguments or per-project configuration. The Dockerfile sets `DOTNET_CLI_HOME`, `DOTNET_NOLOGO` and `ASPIRE_CLI_TELEMETRY_OPTOUT` for any process Claude Code spawns.

## Goals / Non-Goals

**Goals:**
- Agents can use the Aspire MCP server from the first session after a container start.
- Nothing is written to the workspace.

**Non-Goals:**
- Running `aspire agent init`, or installing Aspire skills or hooks.
- Starting or managing an AppHost; that stays a manual or agent-driven step on the allocated ports.
- Registering it for host-side Claude Code.

## Decisions

- **Copy the serena approach**: one `jq` edit of `~/.claude.json` per start, so it survives volume changes and needs no plugin. Alternative, `claude mcp add --scope user`, was rejected: it is slower to start and harder to test with a stubbed config path.
- **Binary path** defaults to `/usr/local/bin/aspire` and is overridable with `CLAUDE_YOLO_ASPIRE_BIN`, mirroring the serena variable so tests can point it at a stub or a missing file.
- **Absolute command path** in the config rather than `aspire`, so it does not depend on `PATH` in the spawned process.
- The block sits directly after the serena block and is independent of it: a missing serena binary must not stop Aspire registration.

## Risks / Trade-offs

- A Claude Code session already running when the entrypoint edits the file does not see the server until restarted; the entrypoint runs before Claude Code starts, so this only affects sessions started by other means.
- If the Aspire CLI is bumped to a version that renames `agent mcp`, the registration silently points at a broken command. The Dockerfile pins the CLI version, so a bump is a deliberate edit and the test and this line change together.
