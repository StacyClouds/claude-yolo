## 1. Remove build-time plugin baking

- [ ] 1.1 Delete the `builder` stage from the `Dockerfile` (git/ssh install, `claude plugin marketplace add` x2, `claude plugin install` x6) and verify the final image no longer references `AS builder` or `--from=builder`
- [ ] 1.2 Remove the two `COPY --from=builder ... /home/node/.claude` and `... /home/node/.claude.json` lines and verify `docker build` succeeds without them
- [ ] 1.3 Remove `--ssh default` from `build_image()` in the `claude-yolo` script and verify `claude-yolo rebuild` succeeds without an ssh-agent forwarded

## 2. Fix npm for the unprivileged node user

- [ ] 2.1 In the final image, after the root-run `npm install -g @anthropic-ai/claude-code @fission-ai/openspec`, determine npm's global prefix (`npm config get prefix` / `npm root -g`) and `chown -R node:node` that path (and its `bin` dir) so it's writable by `node`
- [ ] 2.2 Verify as the `node` user inside a running container: `npm install -g cowsay` (or similar throwaway package) succeeds without an EACCES/read-only error
- [ ] 2.3 Verify `npm config get cache` resolves to a path writable by `node` (e.g. under `/home/node/.npm`) and that an install populates it without error

## 3. Add serena's MCP runtime (Python + uv)

- [ ] 3.1 Add Python 3 and `uv` (providing `uvx`) to the final image stage, available on `PATH` for the `node` user
- [ ] 3.2 Verify `uvx --version` runs successfully as the `node` user inside the container
- [ ] 3.3 With the `serena` plugin configured (via a mounted `~/.claude` containing it, per section 4), verify Claude Code inside the container can connect to serena's MCP server without a connection error

## 4. Mount host ~/.claude as the sandbox's global config

- [ ] 4.1 In the `claude-yolo` script, replace `CLAUDE_MD_MOUNT` (single-file mount of `~/.claude/CLAUDE.md`) with a mount of the whole `$HOME/.claude` folder read-only at `/home/node/.claude`, conditional on the host directory existing
- [ ] 4.2 Verify `claude-yolo run` with a host `~/.claude` present exposes its settings/agents/skills/plugins/commands inside the container at `/home/node/.claude`
- [ ] 4.3 Verify a write attempt from inside the container to a path under `/home/node/.claude` fails (read-only mount holds)
- [ ] 4.4 Verify `claude-yolo run` still starts normally when the host has no `~/.claude` directory (mount is skipped, no error)
- [ ] 4.5 Verify editing a file under the host's `~/.claude` and re-running `claude-yolo run` (no rebuild) picks up the change inside the container

## 5. Update specs to match

- [ ] 5.1 Run `openspec validate --change fix-sandbox-npm-serena-host-claude --strict` and resolve any reported issues
