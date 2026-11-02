#!/bin/sh
# Tests for entrypoint.sh's default status line (see
# openspec/changes/bake-statusline-into-image). entrypoint.sh is run against
# temporary host/local/baked directories, selected through its
# CLAUDE_YOLO_* path overrides, with a stub `tini` on PATH so the final
# `exec tini -- "$@"` returns immediately. No Docker daemon is needed.
#
# Usage: sh test/entrypoint.test.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENTRYPOINT="$SCRIPT_DIR/entrypoint.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $1"
}

# entrypoint.sh rewrites settings.json and .claude.json under its configured
# paths. Without overrides those are the real /home/node paths, so refuse to
# run any scenario unless every path is overridable.
for var in HOST_CLAUDE LOCAL_CLAUDE CLAUDE_JSON BAKED_SKILLS BAKED_STATUSLINE OPENSPEC_BAKED SERENA_BIN; do
    if grep -qE "^$var=\"\\$\\{CLAUDE_YOLO_$var:-" "$ENTRYPOINT"; then
        pass
    else
        fail "entrypoint.sh must set $var from CLAUDE_YOLO_$var, defaulting to its current value"
    fi
done
if [ "$FAIL_COUNT" -ne 0 ]; then
    echo "Refusing to run scenarios against real paths: $FAIL_COUNT failed, $PASS_COUNT passed"
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
printf '#!/bin/sh\nexit 0\n' > "$STUB_BIN/tini"
chmod +x "$STUB_BIN/tini"

DEFAULT_STATUS_COMMAND='bash ~/.claude/statusline-command.sh'

# new_sandbox <name>: fresh host/local/baked directories under $WORK/<name>,
# with a baked default script and no host content yet.
new_sandbox() {
    SB="$WORK/$1"
    HOST="$SB/host"
    LOCAL="$SB/local"
    BAKED="$SB/baked-statusline"
    mkdir -p "$HOST" "$LOCAL" "$BAKED"
    echo '# baked default' > "$BAKED/statusline-command.sh"
}

run_entrypoint() {
    HOST_ARG="${1:-$HOST}"
    PATH="$STUB_BIN:$PATH" \
    CLAUDE_YOLO_HOST_CLAUDE="$HOST_ARG" \
    CLAUDE_YOLO_LOCAL_CLAUDE="$LOCAL" \
    CLAUDE_YOLO_CLAUDE_JSON="$SB/claude.json" \
    CLAUDE_YOLO_BAKED_SKILLS="$SB/no-baked-skills" \
    CLAUDE_YOLO_BAKED_STATUSLINE="$BAKED" \
    CLAUDE_YOLO_OPENSPEC_BAKED="$SB/no-openspec-baked" \
    CLAUDE_YOLO_SERENA_BIN="$SB/no-serena" \
        sh "$ENTRYPOINT" true >"$SB/out" 2>"$SB/err" || {
            fail "$CURRENT: entrypoint exited non-zero: $(cat "$SB/err")"
            return 1
        }
}

expect_file_content() {
    # expect_file_content <file> <expected> <message>
    if [ -f "$1" ]; then
        got="$(cat "$1")"
    else
        got='<missing>'
    fi
    if [ "$got" = "$2" ]; then
        pass
    else
        fail "$CURRENT: $3 (expected '$2', got '$got')"
    fi
}

expect_status_line() {
    # expect_status_line <command> <message>
    actual="$(jq -c '.statusLine' "$LOCAL/settings.json" 2>/dev/null || echo '<unreadable>')"
    want="$(jq -cn --arg c "$1" '{type: "command", command: $c, padding: 0}')"
    if [ "$actual" = "$want" ]; then
        pass
    else
        fail "$CURRENT: $2 (expected $want, got $actual)"
    fi
}

# --- Host provides neither script nor setting ---
CURRENT="neither script nor setting"
new_sandbox neither
echo '{"theme":"dark"}' > "$HOST/settings.json"
if run_entrypoint; then
    expect_file_content "$LOCAL/statusline-command.sh" '# baked default' "default script is installed"
    expect_status_line "$DEFAULT_STATUS_COMMAND" "statusLine runs the script"
fi

# --- No host ~/.claude folder ---
CURRENT="no host folder"
new_sandbox nohost
if run_entrypoint "$SB/does-not-exist"; then
    expect_file_content "$LOCAL/statusline-command.sh" '# baked default' "default script is installed"
    expect_status_line "$DEFAULT_STATUS_COMMAND" "statusLine runs the script"
fi

# --- Host provides its own script ---
CURRENT="host script"
new_sandbox hostscript
echo '# host script' > "$HOST/statusline-command.sh"
echo '{}' > "$HOST/settings.json"
if run_entrypoint; then
    expect_file_content "$LOCAL/statusline-command.sh" '# baked default' "host script is ignored in favour of the baked one"
fi

# --- Host provides its own statusLine setting ---
CURRENT="host statusLine"
new_sandbox hostsetting
echo '{"statusLine":{"type":"command","command":"echo custom","padding":2}}' > "$HOST/settings.json"
if run_entrypoint; then
    actual="$(jq -c '.statusLine' "$LOCAL/settings.json")"
    want="$(jq -cn --arg c "$DEFAULT_STATUS_COMMAND" '{type: "command", command: $c, padding: 0}')"
    if [ "$actual" = "$want" ]; then
        pass
    else
        fail "$CURRENT: host statusLine must be replaced by the container's (got $actual)"
    fi
fi

# --- Host provides a script but no statusLine setting ---
CURRENT="host script without setting"
new_sandbox scriptnosetting
echo '# host script' > "$HOST/statusline-command.sh"
echo '{}' > "$HOST/settings.json"
if run_entrypoint; then
    expect_file_content "$LOCAL/statusline-command.sh" '# baked default' "baked script is used"
    expect_status_line "$DEFAULT_STATUS_COMMAND" "statusLine runs the baked script"
fi

# --- Default script is refreshed on a volume that holds an older default ---
CURRENT="stale default"
new_sandbox stale
echo '{}' > "$HOST/settings.json"
echo '# old default' > "$LOCAL/statusline-command.sh"
if run_entrypoint; then
    expect_file_content "$LOCAL/statusline-command.sh" '# baked default' "a newer baked default replaces the old one"
fi

# --- Repeated starts on the same volume ---
CURRENT="repeated starts"
new_sandbox repeat
echo '{}' > "$HOST/settings.json"
if run_entrypoint; then
    first="$(jq -S . "$LOCAL/settings.json")"
    if run_entrypoint; then
        second="$(jq -S . "$LOCAL/settings.json")"
        if [ "$first" = "$second" ] && [ "$(jq '[.statusLine] | length' "$LOCAL/settings.json")" -eq 1 ]; then
            pass
        else
            fail "$CURRENT: settings.json must be identical after a second start"
        fi
        expect_status_line "$DEFAULT_STATUS_COMMAND" "statusLine is unchanged after a second start"
    fi
fi

echo "$PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
