# aspire-mcp-runtime Specification

## Purpose
Make the Aspire MCP server available to Claude Code inside the sandbox container, so agents can query Aspire dashboards running in the same container, without writing project files into the mounted workspace.

## Requirements

### Requirement: Aspire MCP server is registered at user scope on every start
When the Aspire CLI binary exists and is executable, the container entrypoint SHALL set `mcpServers.aspire` in `~/.claude.json` to a stdio server that runs the binary with the arguments `agent mcp`. It SHALL do so on every start, replacing any previous `mcpServers.aspire` value, and SHALL preserve all other keys in the file, including other MCP servers.

#### Scenario: Fresh volume without an aspire entry
- **WHEN** the entrypoint runs, the Aspire binary is executable, and `~/.claude.json` has no `mcpServers.aspire`
- **THEN** `mcpServers.aspire` is `{command: <binary path>, args: ["agent", "mcp"], env: {}, type: "stdio"}`

#### Scenario: Stale entry is replaced
- **WHEN** the entrypoint runs and `mcpServers.aspire` already exists with a different command
- **THEN** it is overwritten with the current binary path and arguments

#### Scenario: Other servers are kept
- **WHEN** the entrypoint runs and `mcpServers.serena` exists
- **THEN** `mcpServers.serena` is unchanged and `mcpServers.aspire` is also present

### Requirement: Registration is skipped without the binary
When the Aspire CLI binary does not exist or is not executable, the entrypoint SHALL NOT add or modify `mcpServers.aspire`, and SHALL still exit successfully.

#### Scenario: Binary missing
- **WHEN** the entrypoint runs and the Aspire binary path does not exist
- **THEN** `~/.claude.json` has no `mcpServers.aspire` and the entrypoint exits with status 0

### Requirement: The workspace is not written to
Registering the Aspire MCP server SHALL NOT create or modify any file under `/workspace`, including `.mcp.json`.

#### Scenario: No project files created
- **WHEN** the entrypoint runs with the Aspire binary present
- **THEN** no `.mcp.json` exists in the workspace as a result
