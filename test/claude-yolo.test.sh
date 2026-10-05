#!/bin/sh
# Tests for claude-yolo's argument parsing (--help, workspace-path override,
# the "--" pass-through separator). No real Docker daemon is used: a fake
# `docker` stub is put on PATH that just logs what it was called with and
# exits 0, so these tests can run anywhere `sh` runs.
#
# Usage: sh test/claude-yolo.test.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_YOLO="$SCRIPT_DIR/claude-yolo"
# Matches claude-yolo's own default: PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)".
DEFAULT_PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/docker" <<'EOF'
#!/bin/sh
# Records the full invocation (one line) to DOCKER_STUB_LOG and succeeds,
# so claude-yolo never touches a real Docker daemon during these tests.
echo "$@" >> "$DOCKER_STUB_LOG"
exit 0
EOF
chmod +x "$STUB_BIN/docker"

OTHER_PROJECT="$WORK/other-project"
mkdir -p "$OTHER_PROJECT"
NONEXISTENT="$WORK/does-not-exist"
CWD_WITH_SUBCOMMAND_DIRS="$WORK/cwd"
mkdir -p "$CWD_WITH_SUBCOMMAND_DIRS/run" "$CWD_WITH_SUBCOMMAND_DIRS/yolo"

LOG="$WORK/docker.log"
ERR="$WORK/stderr"
OUT="$WORK/stdout"
EXIT_CODE=0

PASS_COUNT=0
FAIL_COUNT=0

# run_cli <cwd> <args...>: invokes claude-yolo with the docker stub on PATH,
# capturing its stdout/stderr/exit code and resetting the docker call log.
run_cli() {
    cli_cwd="$1"
    shift
    : > "$LOG"
    EXIT_CODE=0
    (cd "$cli_cwd" && PATH="$STUB_BIN:$PATH" DOCKER_STUB_LOG="$LOG" "$CLAUDE_YOLO" "$@") >"$OUT" 2>"$ERR" || EXIT_CODE=$?
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $1"
}

expect_exit_code() {
    if [ "$EXIT_CODE" -eq "$1" ]; then
        pass
    else
        fail "$2 (expected exit code $1, got $EXIT_CODE; stderr: $(cat "$ERR"))"
    fi
}

expect_log_contains() {
    if grep -qF -- "$1" "$LOG"; then
        pass
    else
        fail "$2 (expected docker log to contain '$1', got: $(cat "$LOG"))"
    fi
}

expect_log_empty() {
    if [ ! -s "$LOG" ]; then
        pass
    else
        fail "$1 (expected no docker calls, got: $(cat "$LOG"))"
    fi
}

expect_stdout_contains() {
    if grep -qF -- "$1" "$OUT"; then
        pass
    else
        fail "$2 (expected stdout to contain '$1', got: $(cat "$OUT"))"
    fi
}

expect_stderr_contains() {
    if grep -qF -- "$1" "$ERR"; then
        pass
    else
        fail "$2 (expected stderr to contain '$1', got: $(cat "$ERR"))"
    fi
}

# --- --help / -h ---

run_cli "$WORK" --help
expect_exit_code 0 "--help exits 0"
expect_stdout_contains "Usage: claude-yolo" "--help prints usage"
expect_log_empty "--help makes no docker calls"

run_cli "$WORK" -h
expect_exit_code 0 "-h exits 0"
expect_stdout_contains "Usage: claude-yolo" "-h prints usage"
expect_log_empty "-h makes no docker calls"

run_cli "$WORK" --help run
expect_exit_code 0 "--help takes priority over other arguments"
expect_log_empty "--help with trailing args still makes no docker calls"

# --- bare positional workspace path ---

run_cli "$WORK" "$OTHER_PROJECT" run
expect_exit_code 0 "bare positional workspace path succeeds"
expect_log_contains "-v $OTHER_PROJECT:/workspace" "bare positional path mounts as /workspace"

run_cli "$WORK" --workspace "$OTHER_PROJECT" run
expect_exit_code 0 "--workspace still works"
expect_log_contains "-v $OTHER_PROJECT:/workspace" "--workspace mounts as /workspace"

run_cli "$WORK" "$NONEXISTENT" run
expect_exit_code 1 "nonexistent bare positional path fails"
expect_stderr_contains "does not exist" "nonexistent path error message"
expect_log_empty "nonexistent path makes no docker calls"

# --- subcommand keywords always win over same-named directories ---

run_cli "$CWD_WITH_SUBCOMMAND_DIRS" run
expect_exit_code 0 "run keyword wins over a sibling './run' directory"
expect_log_contains "-v $DEFAULT_PROJECT_DIR:/workspace" "default workspace used, not the local run/ directory"

run_cli "$CWD_WITH_SUBCOMMAND_DIRS" yolo
expect_exit_code 0 "yolo keyword wins over a sibling './yolo' directory"
expect_log_contains "-v $DEFAULT_PROJECT_DIR:/workspace" "default workspace used, not the local yolo/ directory"

# --- -- pass-through separator ---

run_cli "$WORK" run -- "review this file"
expect_exit_code 0 "run -- forwards args"
expect_log_contains "claude review this file" "run -- forwards args verbatim to claude"

run_cli "$WORK" -- "fix the bug"
expect_exit_code 0 "no-args default -- forwards args"
expect_log_contains "claude --dangerously-skip-permissions fix the bug" "default mode -- forwards args verbatim to claude"

run_cli "$WORK" run -- --model opus -p "one-shot query"
expect_exit_code 0 "claude's own flags pass through unchanged"
expect_log_contains "claude --model opus -p one-shot query" "claude flags forwarded verbatim"

run_cli "$WORK" run "review this file"
expect_exit_code 1 "run without -- before prompt text fails"
expect_stderr_contains "--" "error mentions the -- separator"
expect_log_empty "missing -- makes no docker calls"

run_cli "$WORK" "fix the bug"
expect_exit_code 1 "no-args default without -- fails"
expect_stderr_contains "--" "no-args-default error mentions the -- separator"
expect_log_empty "no-args-default missing -- makes no docker calls"

echo ""
echo "Passed: $PASS_COUNT, Failed: $FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
