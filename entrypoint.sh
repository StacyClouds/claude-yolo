#!/bin/sh
# Syncs specific config items from the read-only host ~/.claude mount (see
# claude-yolo script) into the writable /home/node/.claude on every
# container start, WITHOUT touching anything else there. Directory items
# are merged (host overlaid on top of local, host wins conflicts); file
# items are fully replaced from the host's copy when it has one — see the
# DIR_ITEMS/FILE_ITEMS split below for why.
#
# /home/node is the claude-yolo-home named volume: it persists across
# container runs so Claude's login/session state survives a container
# being closed and only goes away on `claude-yolo nuke`. Directly mounting
# the whole host ~/.claude read-only over /home/node/.claude (the old
# approach) shadowed that entire path, so Claude could never write its own
# .credentials.json there and login was lost on every run. Copying in only
# the known host-config items, and leaving everything else (credentials,
# sessions, project trust decisions, todos, shell snapshots, etc.) alone,
# keeps the "sandbox uses the host's settings/agents/skills/plugins"
# behavior while letting Claude's own runtime state persist normally.
#
# Also, unconditionally on every start (host mount or not): pre-accepts
# workspace trust for /workspace in ~/.claude.json, and backfills the
# Anthropic "frontend-design" skill from the image if nothing else already
# provided one under that name.
set -eu

HOST_CLAUDE=/home/node/.claude-host
LOCAL_CLAUDE=/home/node/.claude
CLAUDE_JSON=/home/node/.claude.json
BAKED_SKILLS=/opt/skills

# Pre-accept the "do you trust the files in this folder?" dialog for the
# project mount. /workspace is always the in-container mount point (see the
# claude-yolo script's `docker run -v ... :/workspace`), so this one fixed
# key is all that's ever needed, regardless of which host path is mounted
# there. Runs on every start (not just first-ever) since a fresh/nuked
# claude-yolo-home volume has no ~/.claude.json yet to remember it in.
[ -f "$CLAUDE_JSON" ] || echo '{}' > "$CLAUDE_JSON"
jq '.projects["/workspace"].hasTrustDialogAccepted = true' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"

# Directory-shaped items are merged (host copy overlaid on top of what's
# already local), not mirrored. Deleting each one before copying the host's
# version in — the old behavior — exactly mirrored the host, but it also
# destroyed anything installed *inside* the running container (e.g. `claude
# plugin install`, or a skill dropped straight into ~/.claude/skills) that
# wasn't also present on the host. Since claude-yolo runs `docker run --rm`,
# every invocation is a fresh container, so that wipe ran on every single
# restart — a runtime-installed skill/plugin never survived long enough to
# be picked up by the next session. Overlaying instead of replacing means
# the host still wins on same-named conflicts, but container-only installs
# persist on the claude-yolo-home volume across restarts, same as Claude's
# own login/session state does.
#
# File-shaped items are still a full replace-from-host, unchanged: merging
# a single file (as opposed to a directory of independently named entries)
# isn't structurally meaningful here. One known gap this leaves: `claude
# plugin install` also flips an `enabledPlugins` key in settings.json, and
# that flag itself still resets to match the host's settings.json on
# restart even though the plugin's own files (now handled by the merge
# below) persist — add the plugin to the host's own settings.json if you
# want it to stay enabled by default too.
DIR_ITEMS="agents commands skills plugins rules workflows"
FILE_ITEMS="CLAUDE.md settings.json settings.local.json keybindings.json statusline-command.sh statusline-command.ps1"

if [ -d "$HOST_CLAUDE" ]; then
    mkdir -p "$LOCAL_CLAUDE"

    # -f: some host items (e.g. a git-cloned plugin marketplace's pack
    # files) are read-only. Without it, re-copying the same file on a later
    # start fails outright — cp can't open an existing read-only
    # destination for writing, even as the owning user — instead of just
    # unlinking and recreating it.
    for item in $DIR_ITEMS; do
        if [ -d "$HOST_CLAUDE/$item" ]; then
            mkdir -p "$LOCAL_CLAUDE/$item"

            # A host item can be a git clone (e.g. a plugin marketplace under
            # plugins/marketplaces/*), and git sometimes leaves .git/objects
            # directories themselves read-only, not just the pack files in
            # them. cp -a preserves that onto the local copy, and -f below
            # only rescues a read-only *file* (it unlinks and retries) — it
            # can't rescue a read-only *directory*, since removing a file
            # needs write permission on its parent dir, not the file itself.
            # Force it writable first; node owns these paths (it created
            # them), so chmod on its own files works regardless of their
            # current mode.
            chmod -R u+w "$LOCAL_CLAUDE/$item" 2>/dev/null || true

            cp -af "$HOST_CLAUDE/$item/." "$LOCAL_CLAUDE/$item/"
        fi
    done

    for item in $FILE_ITEMS; do
        if [ -e "$HOST_CLAUDE/$item" ]; then
            cp -af "$HOST_CLAUDE/$item" "$LOCAL_CLAUDE/$item"
        fi
    done

    # The host's settings may set permissions.blockReadsOutsideWorkingDirectories,
    # which forces a read-permission prompt outside the working directory even
    # under `claude --dangerously-skip-permissions` (Claude Code 2.1.257+) —
    # defeating the whole point of this sandbox, whose isolation already comes
    # from the container boundary, not from that setting. Force it off in both
    # settings files inside the container only; the host's own settings.json
    # (and its own Claude sessions) are untouched.
    for f in settings.json settings.local.json; do
        path="$LOCAL_CLAUDE/$f"
        if [ -f "$path" ]; then
            jq 'if .permissions and (.permissions | has("blockReadsOutsideWorkingDirectories")) then .permissions.blockReadsOutsideWorkingDirectories = false else . end' \
                "$path" > "$path.tmp"
            mv "$path.tmp" "$path"
        fi
    done
fi

# Force-accept the "Bypass Permissions mode" confirmation dialog. Claude Code
# persists your acceptance of it as skipDangerousModePermissionPrompt in the
# global user settings.json — normally a one-time flag set the first time you
# click "Accept" in the TUI. But the host-config sync above fully replaces
# settings.json with the host's own copy (which doesn't have this sandbox-only
# flag) on every start, silently wiping any acceptance recorded during a
# previous container's life, so the dialog came back every single run. Forcing
# it back on here — unconditionally, even with no host mount, so a first-ever
# container also skips it — makes `claude-yolo yolo` actually mean YOLO by
# default, consistent with the sandbox's isolation already coming from the
# container boundary rather than from Claude's own confirmation prompts.
mkdir -p "$LOCAL_CLAUDE"
[ -f "$LOCAL_CLAUDE/settings.json" ] || echo '{}' > "$LOCAL_CLAUDE/settings.json"
jq '.skipDangerousModePermissionPrompt = true' "$LOCAL_CLAUDE/settings.json" > "$LOCAL_CLAUDE/settings.json.tmp"
mv "$LOCAL_CLAUDE/settings.json.tmp" "$LOCAL_CLAUDE/settings.json"

# The serena plugin's own .mcp.json (synced from the host's ~/.claude above,
# or from a fresh marketplace install inside the container) launches it via
# `uvx --from git+https://github.com/oraios/serena serena start-mcp-server`.
# uv resolves that "git+" spec by shelling out to a real `git` binary, which
# this sandbox deliberately never has (see the Dockerfile) - so left as-is,
# serena's MCP server can never even download, let alone start. The
# Dockerfile's serena-builder stage pre-installs it at build time instead;
# rewrite every copy of serena's .mcp.json still pointing at the git+
# invocation to call that pre-baked binary directly, so no git operation is
# ever attempted at runtime. Only rewrites the exact shape the marketplace
# ships today, so an unrelated or already-patched .mcp.json is left alone.
SERENA_BIN=/opt/serena-tool/bin/serena
if [ -x "$SERENA_BIN" ]; then
    find "$LOCAL_CLAUDE/plugins" -name ".mcp.json" 2>/dev/null | while IFS= read -r f; do
        if jq -e --arg url "git+https://github.com/oraios/serena" \
            '.serena.command == "uvx" and ((.serena.args // []) | index($url)) != null' \
            "$f" >/dev/null 2>&1
        then
            jq --arg bin "$SERENA_BIN" '.serena.command = $bin | .serena.args = ["start-mcp-server"]' \
                "$f" > "$f.tmp"
            mv "$f.tmp" "$f"
        fi
    done

    # Independently of whether a serena plugin was ever installed (host- or
    # container-side), register serena directly as a user-scope MCP server
    # in ~/.claude.json every start, so it's always available regardless of
    # plugin state or which claude-yolo-home volume is currently mounted.
    # --context ide-assistant: serena's recommended context for CLI coding
    # agents (as opposed to its "desktop-app" default). --project-from-cwd:
    # auto-detects /workspace as the active project via its .git dir, with
    # no per-project serena config required.
    jq --arg bin "$SERENA_BIN" \
        '.mcpServers.serena = {command: $bin, args: ["start-mcp-server", "--context", "ide-assistant", "--project-from-cwd"], env: {}, type: "stdio"}' \
        "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
    mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
fi

# Backfill baked-in fallback content — the Anthropic "frontend-design"
# skill, and OpenSpec's `opsx:*` commands/openspec-* skills — that the
# host's own ~/.claude (merged above) doesn't already provide by the same
# name. Host content always wins; this only fills gaps left after the
# merge. All of it is baked outside /home/node (see the Dockerfile) so it
# survives being copied in here on every start, rather than being baked
# straight into /home/node/.claude where the persisted claude-yolo-home
# volume would shadow it after the very first run.
backfill() {
    src="$1"
    dst="$2"
    [ -d "$src" ] || return 0
    mkdir -p "$dst"
    for entry in "$src"/*; do
        name="$(basename "$entry")"
        [ -e "$dst/$name" ] || cp -a "$entry" "$dst/$name"
    done
}

backfill "$BAKED_SKILLS" "$LOCAL_CLAUDE/skills"
backfill /opt/openspec-baked/.claude/skills "$LOCAL_CLAUDE/skills"
backfill /opt/openspec-baked/.claude/commands "$LOCAL_CLAUDE/commands"

exec tini -- "$@"
