## 1. Red: failing tests

- [x] 1.1 Add the test override `CLAUDE_YOLO_ASPIRE_BIN` to `run_entrypoint` in `test/entrypoint.test.sh` (pointing at a missing path by default) and add its name to the variable-existence check
- [x] 1.2 Add a test: with an executable stub binary, `mcpServers.aspire` equals `{command: <stub>, args: ["agent","mcp"], env: {}, type: "stdio"}`; run it and confirm it fails
- [x] 1.3 Add a test: a stale `mcpServers.aspire` is replaced
- [x] 1.4 Add a test: an existing `mcpServers.serena` is preserved alongside the new entry
- [x] 1.5 Add a test: with a missing binary, no `mcpServers.aspire` is added and the entrypoint exits 0
- [x] 1.6 Add a test: no `.mcp.json` appears in the workspace

## 2. Green: implementation

- [x] 2.1 Add the registration block to `entrypoint.sh` after the serena block, using `ASPIRE_BIN="${CLAUDE_YOLO_ASPIRE_BIN:-/usr/local/bin/aspire}"` and an executable check
- [x] 2.2 Run `test/entrypoint.test.sh` and confirm all tests pass

## 3. Verify and document

- [x] 3.1 Mention the Aspire MCP registration in `README.md` next to the serena description
- [x] 3.2 Rebuild the image, start a container, and confirm `~/.claude.json` contains `mcpServers.aspire` and that `aspire agent mcp` starts
- [x] 3.3 Run `openspec validate register-aspire-mcp`
