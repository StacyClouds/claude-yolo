## Why

Three sandbox problems compound each other right now: the `serena` plugin's MCP server can't connect inside the container, `npm` can't write to its own global install folder as the unprivileged `node` user, and the container only ever sees a single mounted file (`CLAUDE.md`) from the host instead of the user's full `~/.claude` setup (settings, agents, skills, plugins, commands). Fixing the mount to expose the whole host `~/.claude` folder also removes the need to bake plugins into the image at build time, which simplifies the Dockerfile and drops the build-time dependency on SSH-forwarded access to private plugin marketplaces.

## What Changes

- Add a Python runtime + `uv`/`uvx` to the final image so the `serena` plugin's MCP server (a `uvx`-launched Python process) can actually start instead of failing to connect.
- Fix npm's global install location so the unprivileged `node` user can run `npm install -g ...` without hitting a read-only/permission error on npm's global folder.
- **BREAKING**: Mount the host's `~/.claude` folder read-only into the container at `/home/node/.claude` (instead of a read-only single-file mount of `~/.claude/CLAUDE.md`), so settings, agents, skills, plugins, and commands from the host are all available inside the sandbox.
- **BREAKING**: Remove the build-time plugin baking (the `builder` Docker stage that adds plugin marketplaces via SSH and runs `claude plugin install`, plus the two `COPY --from=builder` steps for `.claude`/`.claude.json`). Plugin configuration now comes exclusively from the host's mounted `~/.claude`; when the host has no `~/.claude` folder, the sandbox starts with no plugins configured.
- Remove `--ssh default` from the image build now that no build step needs to authenticate to a private plugin marketplace repo.
- Keep the existing build-time `openspec init` baking of opsx commands/skills as a fallback for when the host has no `~/.claude` folder to mount; document that when a host `~/.claude` is mounted, it shadows that baked-in content at the same path, so opsx availability then depends on whether the host's own `~/.claude` has it.

## Capabilities

### New Capabilities
- `sandbox/host-claude-config`: mounts the host's `~/.claude` folder read-only into the container as the global Claude Code configuration (settings, agents, skills, plugins, commands), replacing the single-file CLAUDE.md mount and the build-time plugin baking.
- `sandbox/npm-tooling`: makes `npm` (including global installs) usable by the unprivileged `node` user inside the container.
- `sandbox/serena-mcp-runtime`: provides the Python/`uv` runtime the `serena` plugin's MCP server needs to launch inside the container.

### Modified Capabilities
- `sandbox/claude-global-instructions`: the single-file `CLAUDE.md` read-only mount is removed; its behavior is superseded by `sandbox/host-claude-config` mounting the whole `~/.claude` folder (which includes `CLAUDE.md`).
- `sandbox/opsx-tooling`: adds a requirement documenting that a mounted host `~/.claude` shadows the build-time baked-in opsx commands/skills at that path, so the existing "available regardless of mounted project" guarantee no longer holds once a host `~/.claude` without opsx scaffolding is mounted.

## Impact

- `Dockerfile`: remove the `builder` stage's plugin marketplace/install steps and the two `COPY --from=builder` lines for `.claude`/`.claude.json`; add a Python + `uv` install; fix npm's global prefix/ownership for the `node` user.
- `claude-yolo` script: replace the single-file `CLAUDE_MD_MOUNT` logic with a mount of the whole host `~/.claude` folder (read-only); drop `--ssh default` from `build_image`.
- `openspec/specs/sandbox/claude-global-instructions/spec.md`: requirements removed (superseded).
- `openspec/specs/sandbox/opsx-tooling/spec.md`: one requirement added.
- No changes to `openspec/specs/sandbox/cli-modes` or `openspec/specs/sandbox/dotnet-toolchain`.
