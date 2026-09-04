## Context

`claude-yolo` (see `add-claude-yolo-cli-modes`) already builds `run_container()`'s `docker run` invocation with a project bind mount, the `claude-yolo-home` volume, and a conditional `ANTHROPIC_API_KEY` env pass-through (`${ANTHROPIC_API_KEY:+-e ANTHROPIC_API_KEY}`). The `Dockerfile`'s final stage already installs .NET SDKs 8/9/10/11-preview via `dotnet-install.sh` into `/usr/share/dotnet`, with `DOTNET_ROOT` and `PATH` set accordingly (see `add-dotnet-and-opsx-baking`).

## Goals / Non-Goals

**Goals:**
- Make the host's global `CLAUDE.md` visible to Claude inside the sandbox, always current, with no rebuild step involved.
- Add `dotnet-stryker` as a usable global tool for the unprivileged `node` user.

**Non-Goals:**
- Baking the global `CLAUDE.md` into the image (rejected — see Decision 1).
- Any change to project-level `CLAUDE.md` handling — those already arrive live via the existing `/workspace` bind mount, untouched by this change.
- Pinning `dotnet-stryker` to a specific version (explicit choice: always latest).
- Any change to `nuke`/`rebuild` semantics.

## Decisions

**1. Bind-mount `~/.claude/CLAUDE.md` at run time, read-only, rather than baking it into the image.**
Baking it in would mean editing the host file has no effect until `claude-yolo rebuild` is run — the exact staleness problem the `add-claude-yolo-cli-modes` change introduced for other floating content, and the opposite of what was asked ("does it copy the *latest* version"). A run-time mount has no such lag and needs no `Dockerfile` change at all. Read-only (`:ro`) keeps the sandbox's "Claude can't touch things outside `/workspace`" posture intact for this new path too.

**2. Mount is conditional on the host file existing, built as a single `--volume=...` token, not a bare `-v` with a missing companion argument.**
`claude-yolo` runs under `set -eu`; referencing `$HOME/.claude/CLAUDE.md` unconditionally would still work syntactically, but Docker would refuse to mount a non-existent host file cleanly (behavior varies, and can silently create an unwanted directory at the target path). The script checks `[ -f "$HOME/.claude/CLAUDE.md" ]` first and only then sets a `CLAUDE_MD_MOUNT` variable, added to the `docker run` args via `${CLAUDE_MD_MOUNT:+"$CLAUDE_MD_MOUNT"}` — the same pattern already used for `ANTHROPIC_API_KEY`. Using the long-form `--volume=host:container:ro` (rather than short `-v host:container:ro` as two separate args) keeps it a single shell token, so the conditional expansion doesn't need an array or `eval`.

**3. Target path inside the container is `/home/node/.claude/CLAUDE.md`.**
`HOME=/home/node` for the `node` user the container runs as, and Claude Code's global-instructions file lives at `$HOME/.claude/CLAUDE.md` — mirroring the host's own `~/.claude/CLAUDE.md` exactly. This path already exists as a directory inside the `claude-yolo-home` volume (populated by the plugin config and opsx bake at image build time); Docker layers the single-file bind mount on top of it without disturbing sibling files (`commands/`, `skills/`, `plugins/`, `settings.json`, etc.).

**4. `dotnet-stryker` installed via `dotnet tool install -g dotnet-stryker`, unpinned, in the final `Dockerfile` stage.**
Matches the user's explicit choice (always latest) and the precedent already set for the .NET 11 preview channel (deliberately floating). Global tools install to `$HOME/.dotnet/tools`; `ENV HOME=/home/node` is moved earlier in the final stage (previously only set right before `USER node`) so this `RUN` step — executed as root, before `USER node` — installs into `/home/node/.dotnet/tools` rather than `/root/.dotnet/tools`. `PATH` gains `/home/node/.dotnet/tools` so `dotnet stryker` resolves as an external `dotnet` verb. The install runs before the existing `chown -R node:node /home/node` step (added for the opsx bake), so that one `chown` also covers `.dotnet/tools` — no separate ownership fix needed.

## Risks / Trade-offs

- **A single-file bind mount inside a named-volume-backed directory** is a well-supported but slightly unusual Docker layering (`-v claude-yolo-home:/home/node` plus `--volume=...:/home/node/.claude/CLAUDE.md:ro` on the same `docker run`). If Docker's behavior here ever surprises (e.g. a future Docker version handling nested mounts differently), the fallback is mounting a whole directory instead of a single file — not needed today.
- **Stryker floating to latest** means a rebuild can pick up a breaking Stryker release with no version bump anywhere to point to, mirroring the same accepted trade-off already made for the .NET 11 preview channel.
- **Moving `ENV HOME=/home/node` earlier in the final stage** changes the environment for the `apt-get`/`dotnet-install.sh` steps too, though none of them read `HOME` today; low risk, but worth a rebuild + full verification pass (not just the new step) to confirm nothing regressed.

## Migration Plan

Local dev CLI/image, not a deployed service. Existing users pick up the `CLAUDE.md` mount and `dotnet-stryker` the next time they pull this change and run `claude-yolo rebuild` (for Stryker) — the mount itself needs no rebuild, since it's script-side. No data migration; rollback is reverting the script and `Dockerfile` edits.
