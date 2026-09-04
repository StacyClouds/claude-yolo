## Context

See `proposal.md` for motivation. Relevant current state:

- `Dockerfile` has a `builder` stage (git+ssh, needed only to add private plugin marketplaces via `docker build --ssh default` and run `claude plugin install`) whose `/home/node/.claude` and `/home/node/.claude.json` are copied into the final image.
- The final image runs `npm install -g @anthropic-ai/claude-code @fission-ai/openspec` as **root**, then later does `chown -R node:node /home/node` (after the `openspec init` bake step) before switching to `USER node`. It never touches ownership of npm's global prefix (`/usr/local/lib/node_modules`, `/usr/local/bin`), which stays root-owned.
- The `claude-yolo` script mounts `$HOME/.claude/CLAUDE.md` read-only at container start (`CLAUDE_MD_MOUNT`), conditional on the file existing on the host.
- `/home/node` is also where the `claude-yolo-home` named Docker volume is mounted, persisting Claude's login/session state across runs. A bind mount at a subpath of `/home/node` (e.g. `/home/node/.claude`) layers on top of that volume, the same way the existing `CLAUDE_MD_MOUNT` already does for one file.
- The `serena` plugin's MCP server is a Python package started via `uvx` (per its upstream install instructions); the final image has no Python or `uv`, so that process can never launch, which is why the MCP connection fails.
- The reported npm failure ("npm folder is read only") matches the global-prefix-ownership gap above: any `npm install -g` run as the unprivileged `node` user fails because it can't write to a root-owned directory.

## Goals / Non-Goals

**Goals:**
- Make `serena`'s MCP server actually able to start inside the sandbox.
- Make `npm install -g` (and npm's cache) work for the `node` user at runtime, not just during the root-run build steps.
- Replace the single-file `CLAUDE.md` mount with a read-only mount of the whole host `~/.claude` folder, and drop build-time plugin baking now that plugin config comes from the host.

**Non-Goals:**
- Preserving write access from inside the sandbox to the host's `~/.claude` folder (explicitly rejected in favor of read-only, matching the sandbox's existing "can't touch host state" model).
- Merging/overlaying host `~/.claude` content with the build-time baked opsx tooling (e.g. via an entrypoint sync step) so both are always available simultaneously. Out of scope for this change; the trade-off (host mount shadows the bake) is accepted and documented in the `sandbox/opsx-tooling` delta.
- Fixing npm permissions for arbitrary mounted project directories under `/workspace` (host-UID-vs-container-UID mismatches). Only the reported symptom - npm's own global folder being unwritable - is in scope.
- Changing how `claude-yolo-home` persists login/session state.

## Decisions

**Drop the `builder` stage entirely, rather than keeping it as a fallback.** Its only purpose was baking plugins via SSH-authenticated marketplace access. With plugin config now sourced from the host's mounted `~/.claude`, there's nothing left for it to do. This also removes `--ssh default` from `build_image` in the `claude-yolo` script and the private-repo SSH dependency at build time. Alternative considered: keep it as a fallback for when the host has no `~/.claude` (per the "keep both" option) - rejected per the user's explicit choice to replace rather than dual-maintain.

**Mount the whole `~/.claude` folder read-only at the same path the image used to bake it (`/home/node/.claude`), analogous to the existing `CLAUDE_MD_MOUNT` pattern.** Conditional on the host folder existing, mirroring the existing missing-file fallback for `CLAUDE.md`. Alternative considered: mount at a different path and merge - adds an entrypoint script and union-mount complexity for no requirement that asked for it.

**Fix npm's global install location by giving the `node` user ownership of npm's global prefix**, rather than reconfiguring npm to use a different `prefix` under `$HOME`. Chowning `/usr/local/lib/node_modules`, `/usr/local/bin`, and `/usr/local/share` (or whichever subset `npm config get prefix` resolves to in the `node:22-bookworm-slim` image) to `node:node` in the final build stage, after the root-run global installs, keeps the existing global binary paths and `PATH` untouched. Alternative considered: set `npm config set prefix ~/.npm-global` and add it to `PATH` - works too, but changes where globally-installed binaries live and adds a `PATH` edit; chowning the existing location is a smaller diff.

**Add Python + `uv` via the official `uv` install script (or Debian's `python3` + `pipx`/`uv` package if available) in the final image stage**, so `uvx` is on `PATH` for the `node` user. `uv` is the tool the `serena` plugin's MCP server documentation launches it with; this is additive and has no interaction with the git-removal isolation model (uv/Python aren't git).

## Risks / Trade-offs

- **[Risk]** Mounting `~/.claude` read-only means Claude Code inside the sandbox can no longer write runtime state it normally keeps under `~/.claude` (e.g. project trust decisions, conversation/session history, shell snapshots, todo state) - previously these lived on the writable `claude-yolo-home` volume. → **Mitigation**: none in this change; accepted per the user's explicit read-only choice. Flagged here so it's a known, deliberate trade-off rather than a surprise; a future change could special-case specific writable subdirectories if this proves disruptive in practice.
- **[Risk]** Once a host `~/.claude` is mounted, opsx commands/skills baked at build time are only available if the host's own `~/.claude` happens to include them. → **Mitigation**: documented as a new requirement on `sandbox/opsx-tooling`; no code mitigation in this change.
- **[Risk]** If the host has no `~/.claude` folder, the sandbox now has zero plugins configured (previously it always had `serena`, `context7`, `honeycomb`, etc. baked in). → **Mitigation**: none; accepted per the user's explicit "replace" choice. The sandbox still starts and functions without plugins.
- **[Risk]** The exact directories `npm config get prefix` resolves to inside `node:22-bookworm-slim` could differ from what's assumed here. → **Mitigation**: verify with `npm config get prefix` and `npm root -g` during implementation rather than hardcoding paths from memory.
