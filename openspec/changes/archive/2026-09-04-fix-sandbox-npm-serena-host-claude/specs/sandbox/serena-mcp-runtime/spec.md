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

### Requirement: serena starts without a runtime git operation
The `serena` plugin's default MCP invocation (`uvx --from git+https://github.com/oraios/serena serena start-mcp-server`) SHALL NOT be used as-is, since `uv` resolves a `git+` dependency spec by shelling out to a real `git` binary, which the sandbox deliberately never has at runtime. The sandbox image SHALL instead provide a pre-installed `serena` command, built from that same source at image build time, and the sandbox SHALL rewrite the plugin's `.mcp.json` (wherever it's synced or installed inside the container) to invoke that pre-installed command directly.

#### Scenario: No git operation attempted at runtime
- **WHEN** the `serena` plugin's MCP server is started inside a running sandbox container
- **THEN** no `git` process SHALL be invoked as part of starting it

#### Scenario: Plugin config still shaped as `uvx` + a `git+` spec
- **WHEN** a copy of serena's `.mcp.json` (synced from the host, or freshly installed from the marketplace inside the container) still has `command: "uvx"` and a `git+https://github.com/oraios/serena` argument
- **THEN** the sandbox SHALL rewrite that file's `serena` command to the pre-installed binary before Claude Code reads it

#### Scenario: Already-patched or unrelated config left alone
- **WHEN** a `.mcp.json` does not match the exact `uvx` + `git+https://github.com/oraios/serena` shape (e.g. it was already rewritten, or belongs to a different MCP server)
- **THEN** the sandbox SHALL leave that file unchanged
