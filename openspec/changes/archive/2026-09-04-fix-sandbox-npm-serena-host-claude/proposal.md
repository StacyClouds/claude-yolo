## Why

Three sandbox problems compound each other right now: the `serena` plugin's MCP server can't connect inside the container, `npm` can't write to its own global install folder as the unprivileged `node` user, and the container only ever sees a single mounted file (`CLAUDE.md`) from the host instead of the user's full `~/.claude` setup (settings, agents, skills, plugins, commands). Fixing the mount to expose the whole host `~/.claude` folder also removes the need to bake plugins into the image at build time, which simplifies the Dockerfile and drops the build-time dependency on SSH-forwarded access to private plugin marketplaces.

## What Changes

- Add a Python runtime + `uv`/`uvx` to the final image so the `serena` plugin's MCP server (a `uvx`-launched Python process) can actually start instead of failing to connect.
- **Pre-install serena at build time instead of via its plugin-provided `uvx --from git+...` invocation**: that invocation requires `uv` to shell out to a real `git` binary, which this sandbox deliberately never has at runtime. A throwaway build stage with a real `git` (public repo, no SSH/credentials needed) installs serena once at build time; `entrypoint.sh` rewrites the plugin's `.mcp.json` to call that pre-installed binary directly, so starting serena's MCP server never needs git at runtime.
- Fix npm's global install location so the unprivileged `node` user can run `npm install -g ...` without hitting a read-only/permission error on npm's global folder.
- **BREAKING**: Mount the host's `~/.claude` folder read-only into the container at `/home/node/.claude-host` (instead of a read-only single-file mount of `~/.claude/CLAUDE.md`), and have the container's entrypoint copy just its config items (settings, agents, skills, plugins, commands, `CLAUDE.md`, etc.) into the writable `/home/node/.claude` on every start, so those are available inside the sandbox while the sandbox's own runtime state at that path (login credentials, sessions, project trust, todos) stays on the persisted `claude-yolo-home` volume instead of being shadowed read-only.
- **BREAKING**: Remove the build-time plugin baking (the `builder` Docker stage that adds plugin marketplaces via SSH and runs `claude plugin install`, plus the two `COPY --from=builder` steps for `.claude`/`.claude.json`). Plugin configuration now comes exclusively from the host's mounted `~/.claude`; when the host has no `~/.claude` folder, the sandbox starts with no plugins configured.
- Remove `--ssh default` from the image build now that no build step needs to authenticate to a private plugin marketplace repo.
- Keep the existing build-time `openspec init` baking of opsx commands/skills as a fallback for when the host has no `~/.claude` folder to mount; document that when a host `~/.claude` is mounted, it shadows that baked-in content at the same path, so opsx availability then depends on whether the host's own `~/.claude` has it.
- Let the folder mounted as `/workspace` be chosen at runtime via a `--workspace <path>` flag on the `claude-yolo` script, instead of it always being the script's hardcoded parent directory. No rebuild required to point at a different project - this is a `docker run -v` argument, not something baked into the image.
- Fix `claude-yolo yolo` requiring the "Bypass Permissions mode" confirmation dialog to be re-accepted on every container start, by having `entrypoint.sh` force `skipDangerousModePermissionPrompt` back on in the container-local `settings.json` after the host-config sync (which otherwise silently discards that acceptance every run).

## Capabilities

### New Capabilities
- `sandbox/host-claude-config`: mounts the host's `~/.claude` folder read-only into the container as the global Claude Code configuration (settings, agents, skills, plugins, commands), replacing the single-file CLAUDE.md mount and the build-time plugin baking.
- `sandbox/npm-tooling`: makes `npm` (including global installs) usable by the unprivileged `node` user inside the container.
- `sandbox/serena-mcp-runtime`: provides the Python/`uv` runtime the `serena` plugin's MCP server needs to launch inside the container.
- `sandbox/openspec-cli`: keeps the `openspec` CLI globally installed and runnable inside the sandbox, independent of the opsx-tooling bake, so a user can run `openspec init` in any mounted project folder to scaffold OpenSpec into it fresh.
- `sandbox/workspace-selection`: lets the caller pick which host folder is mounted as `/workspace` at runtime via a `--workspace <path>` flag, instead of it always being the script's parent directory.

### Modified Capabilities
- `sandbox/claude-global-instructions`: the single-file `CLAUDE.md` read-only mount is removed; its behavior is superseded by `sandbox/host-claude-config` mounting the whole `~/.claude` folder (which includes `CLAUDE.md`).
- `sandbox/opsx-tooling`: adds a requirement documenting that a mounted host `~/.claude` shadows the build-time baked-in opsx commands/skills at that path, so the existing "available regardless of mounted project" guarantee no longer holds once a host `~/.claude` without opsx scaffolding is mounted.

## Impact

- `Dockerfile`: remove the `builder` stage's plugin marketplace/install steps and the two `COPY --from=builder` lines for `.claude`/`.claude.json`; add a Python + `uv` install; add a new `serena-builder` stage (real `git`, throwaway) that pre-installs serena into `/opt/serena-tool`, copied into the final stage; fix npm's global prefix/ownership for the `node` user; bake in `entrypoint.sh` and switch `ENTRYPOINT` to run it (it syncs host config into `~/.claude` before exec-ing `tini`).
- `entrypoint.sh` (new file): copies a fixed list of config items from `/home/node/.claude-host` into `/home/node/.claude` on every container start, leaving everything else under `/home/node/.claude` untouched; forces `skipDangerousModePermissionPrompt = true` into `/home/node/.claude/settings.json` afterward, unconditionally, so the bypass-permissions dialog stays accepted; and rewrites any synced serena `.mcp.json` still shaped as `uvx --from git+...` to call the pre-installed `/opt/serena-tool/bin/serena` directly.
- `.dockerignore`: allow `entrypoint.sh` through (it was previously `**`-excluded, blocking the `COPY`).
- `claude-yolo` script: replace the single-file `CLAUDE_MD_MOUNT` logic with a read-only mount of the whole host `~/.claude` folder at `/home/node/.claude-host`; drop `--ssh default` from `build_image`; add `--workspace <path>` parsing that overrides `PROJECT_DIR`.
- `openspec/specs/sandbox/claude-global-instructions/spec.md`: requirements removed (superseded).
- `openspec/specs/sandbox/opsx-tooling/spec.md`: one requirement added.
- No changes to `openspec/specs/sandbox/cli-modes` or `openspec/specs/sandbox/dotnet-toolchain`, and no changes to how the `openspec` npm package itself is installed (it stays in the final image stage, unaffected by removing the `builder` stage).
