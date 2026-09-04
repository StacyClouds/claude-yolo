## Purpose

Provides the Python and `uv`/`uvx` runtime the `serena` plugin's MCP server needs to start, so its MCP connection can actually be established inside the sandbox instead of failing.

## ADDED Requirements

### Requirement: uv/uvx is available inside the sandbox
The sandbox image SHALL provide `uvx` (from `uv`) on the `PATH` for the `node` user.

#### Scenario: uvx present
- **WHEN** `uvx --version` is run inside the container as the `node` user
- **THEN** it SHALL print a version number rather than a command-not-found error

### Requirement: serena MCP server can start
When the `serena` plugin is configured for Claude Code inside the sandbox, its MCP server process SHALL be able to start successfully.

#### Scenario: MCP connection succeeds
- **WHEN** Claude Code inside the sandbox has the `serena` plugin configured and attempts to connect to its MCP server
- **THEN** the MCP server process SHALL start and the connection SHALL be established, rather than failing to connect
