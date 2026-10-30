## Context

`entrypoint.sh` already copies `statusline-command.sh` and `statusline-command.ps1` from the read-only host mount into `/home/node/.claude` as file items, and replaces `settings.json` from the host's copy on every start. It also backfills baked content from `/opt` (the `frontend-design` skill, OpenSpec commands and skills) into `/home/node/.claude` when the host did not provide an entry of the same name. `/home/node` is the `claude-yolo-home` volume, so content baked directly into it would not reach an existing volume.

`statusline-command.sh` reads Claude Code's status JSON with `jq` and calls `git -C <dir> --no-optional-locks branch --show-current`, discarding errors. `git-wrapper.sh` delegates every subcommand except `push` and `send-pack` to `/usr/bin/git`, so the branch lookup is unaffected.

## Goals / Non-Goals

**Goals:**
- A container started from a freshly built image shows the status line with no host configuration.
- Host-provided script and `statusLine` setting always win.

**Non-Goals:**
- Baking `statusline-command.ps1`; the container is Linux only.
- Changing how any other `settings.json` key or hook is synced. Hooks that reference paths absent from the container are a separate concern.
- Keeping the repository copy of the script in sync with `~/.claude/statusline-command.sh` automatically.

## Decisions

**Bake to `/opt/statusline/statusline-command.sh`, backfill on start.** Follows the existing pattern for baked defaults and avoids the empty-volume seeding problem. Alternative: copy into `/home/node/.claude` in the Dockerfile; rejected because existing volumes would never receive it.

**Install the baked script whenever the host does not provide `statusline-command.sh`.** The host sync runs first, so a host-provided copy is never touched. When the host has none, the baked copy replaces any copy already on the volume, so a rebuilt image's newer default reaches an existing `claude-yolo-home` volume. Alternative: copy only when the file is absent; rejected because a volume would keep an outdated default indefinitely.

**Set `statusLine` with `jq`, only when absent.** Runs after the host `settings.json` sync and alongside the existing `skipDangerousModePermissionPrompt` step, using `.statusLine //= {type: "command", command: "bash ~/.claude/statusline-command.sh", padding: 0}`. This covers the no-host-folder case, because that step already creates `settings.json` when missing. It also covers a host script without a host setting.

**Make the entrypoint's fixed paths overridable by `CLAUDE_YOLO_*` environment variables defaulting to the current values.** The tests run `entrypoint.sh` against temporary directories with a stub `tini` on `PATH`, the same stub approach `test/claude-yolo.test.sh` uses for `docker`. Production behaviour is unchanged when the variables are unset.

## Risks / Trade-offs

- Repository copy and the author's `~/.claude` copy can drift → the repository copy is the default for new containers only; a host copy still wins.
- The script uses Nerd Font glyphs → terminals without such a font show placeholder boxes; unaffected by this change.
- Existing images keep the old behaviour until `claude-yolo rebuild` → stated in the proposal's impact.
