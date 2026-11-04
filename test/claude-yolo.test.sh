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
# DOCKER_STUB_NO_IMAGE=1 makes `docker image inspect` fail, as if no image is built.
if [ "${DOCKER_STUB_NO_IMAGE:-}" = 1 ] && [ "${1:-} ${2:-}" = "image inspect" ]; then exit 1; fi
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
    (cd "$cli_cwd" && HOME="${TEST_HOME:-$HOME}" PATH="$STUB_BIN:$PATH" DOCKER_STUB_LOG="$LOG" "$CLAUDE_YOLO" "$@") >"$OUT" 2>"$ERR" || EXIT_CODE=$?
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

# --- --ports ---

run_cli "$WORK" --ports 5100 run -- hi
expect_exit_code 0 "--ports 5100 exits 0"
expect_log_contains "-p 127.0.0.1:5100-5119:5100-5119" "--ports publishes 20 loopback ports, same numbers both sides"
expect_log_contains "CLAUDE_YOLO_BASE_PORT=5100" "--ports passes base port into the container"
expect_log_contains "CLAUDE_YOLO_PORT_COUNT=20" "--ports passes port count into the container"

run_cli "$WORK" "$OTHER_PROJECT" --ports 6000 run
expect_exit_code 0 "workspace path then --ports exits 0"
expect_log_contains "-v $OTHER_PROJECT:/workspace" "workspace path still honoured with --ports"
expect_log_contains "127.0.0.1:6000-6019:6000-6019" "--ports after workspace path publishes range"

run_cli "$WORK" run
if grep -qF -- " -p " "$LOG"; then fail "no --ports publishes nothing (got: $(cat "$LOG"))"; else pass; fi

run_cli "$WORK" --ports
expect_exit_code 1 "--ports without value fails"
run_cli "$WORK" --ports abc run
expect_exit_code 1 "--ports non-numeric fails"
run_cli "$WORK" --ports 80 run
expect_exit_code 1 "--ports below 1024 fails"
run_cli "$WORK" --ports 65530 run
expect_exit_code 1 "--ports range overflowing 65535 fails"
expect_log_empty "invalid --ports makes no docker calls"


# --- rebuild refreshes Claude Code despite cached layers ---

run_cli "$WORK" rebuild
expect_exit_code 0 "rebuild exits 0"
expect_log_contains "build" "rebuild runs docker build"
expect_log_contains "--pull" "rebuild refreshes the base image"
expect_log_contains "--build-arg CLAUDE_CODE_CACHE_BUST=" "rebuild passes a cache-busting build arg"
first_bust="$(grep -o 'CLAUDE_CODE_CACHE_BUST=[0-9]*' "$LOG" | head -n 1)"
sleep 1
run_cli "$WORK" rebuild
second_bust="$(grep -o 'CLAUDE_CODE_CACHE_BUST=[0-9]*' "$LOG" | head -n 1)"
if [ -n "$first_bust" ] && [ "$first_bust" != "$second_bust" ]; then
    pass
else
    fail "consecutive rebuilds use different cache-bust values (got '$first_bust' then '$second_bust')"
fi

DOCKER_STUB_NO_IMAGE=1
export DOCKER_STUB_NO_IMAGE
run_cli "$WORK" run
expect_log_contains "build -t" "run builds the image when it is missing"
if grep -qF -- "CLAUDE_CODE_CACHE_BUST" "$LOG" || grep -qF -- "--pull" "$LOG"; then
    fail "automatic first build must not pass rebuild-only flags (got: $(cat "$LOG"))"
else
    pass
fi
unset DOCKER_STUB_NO_IMAGE

# --- --secrets: share the workspace's .NET user secrets (see
# openspec/changes/share-host-user-secrets) ---
TEST_HOME="$WORK/home"
export TEST_HOME
SECRETS_STORE="$TEST_HOME/.microsoft/usersecrets"
mkdir -p "$SECRETS_STORE/abc-123" "$SECRETS_STORE/other" "$SECRETS_STORE/props-9" "$TEST_HOME/.microsoft/x"
SEC_WS="$WORK/secws"
mkdir -p "$SEC_WS/src/App" "$SEC_WS/src/NoHost" "$SEC_WS/src/Bad"
printf '<Project><PropertyGroup>\n  <UserSecretsId> abc-123 </UserSecretsId>\n</PropertyGroup></Project>\n' > "$SEC_WS/src/App/App.csproj"
printf '<Project><PropertyGroup><UserSecretsId>nohost-1</UserSecretsId></PropertyGroup></Project>\n' > "$SEC_WS/src/NoHost/NoHost.csproj"
printf '<Project><PropertyGroup><UserSecretsId>props-9</UserSecretsId></PropertyGroup></Project>\n' > "$SEC_WS/Directory.Build.props"
printf '<Project><PropertyGroup><UserSecretsId>../x</UserSecretsId><UserSecretsId>.</UserSecretsId><UserSecretsId>..</UserSecretsId></PropertyGroup></Project>\n' > "$SEC_WS/src/Bad/Bad.csproj"
SEC_MOUNT="-v $SECRETS_STORE/abc-123:/home/node/.microsoft/usersecrets/abc-123:ro"

run_cli "$WORK" "$SEC_WS" run
expect_exit_code 0 "without --secrets still starts"
if grep -qF -- "usersecrets" "$LOG" || grep -qF -- "CLAUDE_YOLO_SECRETS" "$LOG"; then
    fail "without --secrets nothing about user secrets may be passed (got: $(cat "$LOG"))"
else
    pass
fi

run_cli "$WORK" "$SEC_WS" --secrets run
expect_exit_code 0 "--secrets starts"
expect_log_contains "$SEC_MOUNT" "--secrets mounts the id found in a .csproj read-only, whitespace trimmed"
expect_log_contains "-v $SECRETS_STORE/props-9:/home/node/.microsoft/usersecrets/props-9:ro" "--secrets finds ids in Directory.Build.props"
expect_log_contains "CLAUDE_YOLO_SECRETS=1" "--secrets tells the container"
if grep -qF -- "usersecrets/other" "$LOG"; then fail "--secrets must not mount ids the workspace does not use"; else pass; fi
if grep -qF -- "nohost-1" "$LOG"; then fail "--secrets must skip ids with no host folder"; else pass; fi
if grep -qE -- 'usersecrets(/\.\.?)?:|\.microsoft/x|\.\./x|:/home/node/\.microsoft/usersecrets/\.' "$LOG"; then
    fail "--secrets must ignore unsafe ids (got: $(cat "$LOG"))"
else
    pass
fi

run_cli "$WORK" "$SEC_WS" --ports 5100 --secrets run
expect_log_contains "$SEC_MOUNT" "--ports then --secrets both work"
expect_log_contains "CLAUDE_YOLO_BASE_PORT=5100" "--ports still applies with --secrets"
run_cli "$WORK" "$SEC_WS" --secrets --ports 5100 run
expect_log_contains "$SEC_MOUNT" "--secrets then --ports both work"
expect_log_contains "CLAUDE_YOLO_BASE_PORT=5100" "--ports applies when after --secrets"

run_cli "$WORK" --help
expect_stdout_contains "--secrets" "--help lists --secrets"

# --- --secrets: ids named only in code, and a root holding many projects ---
CODE_GUID="fcf4d744-3547-4e43-abb4-be4dd7f1fbfb"
BIN_GUID="bbbbbbbb-1111-2222-3333-444444444444"
MD_GUID="dddddddd-1111-2222-3333-444444444444"
UNUSED_GUID="eeeeeeee-1111-2222-3333-444444444444"
mkdir -p "$SECRETS_STORE/$CODE_GUID" "$SECRETS_STORE/lit-id" "$SECRETS_STORE/$BIN_GUID" \
    "$SECRETS_STORE/$MD_GUID" "$SECRETS_STORE/$UNUSED_GUID" "$SECRETS_STORE/proj-b" "$SECRETS_STORE/fs-id"
ROOT_WS="$WORK/rootws"
mkdir -p "$ROOT_WS/apphost" "$ROOT_WS/other/src" "$ROOT_WS/apphost/bin/Debug" "$ROOT_WS/apphost/node_modules/x" "$ROOT_WS/docs" "$ROOT_WS/fsapp"
cat > "$ROOT_WS/apphost/SiteResource.cs" <<CSEOF
public static class SiteResource {
    private const string SiteUserSecretsId = "$CODE_GUID";
    public static void Add(IConfigurationBuilder c) { c.AddUserSecrets(SiteUserSecretsId); c.AddUserSecrets("lit-id"); }
}
CSEOF
printf '<Project><PropertyGroup><UserSecretsId>proj-b</UserSecretsId></PropertyGroup></Project>\n' > "$ROOT_WS/other/src/B.csproj"
printf 'let c = b.AddUserSecrets<Program>("fs-id")\n' > "$ROOT_WS/fsapp/Program.fs"
printf 'var x = "%s";\n' "$BIN_GUID" > "$ROOT_WS/apphost/bin/Debug/Gen.cs"
printf 'var x = "%s";\n' "$BIN_GUID" > "$ROOT_WS/apphost/node_modules/x/y.cs"
printf 'Notes: %s\n' "$MD_GUID" > "$ROOT_WS/docs/notes.md"

run_cli "$WORK" "$ROOT_WS" --secrets run
expect_exit_code 0 "--secrets on a root folder starts"
expect_log_contains "$SECRETS_STORE/$CODE_GUID:/home/node/.microsoft/usersecrets/$CODE_GUID:ro" "id held in a constant and passed by name is mounted"
expect_log_contains "$SECRETS_STORE/lit-id:/home/node/.microsoft/usersecrets/lit-id:ro" "literal AddUserSecrets(\"id\") is mounted"
expect_log_contains "$SECRETS_STORE/fs-id:/home/node/.microsoft/usersecrets/fs-id:ro" "literal AddUserSecrets<T>(\"id\") in an .fs file is mounted"
expect_log_contains "$SECRETS_STORE/proj-b:/home/node/.microsoft/usersecrets/proj-b:ro" "id from a project in another folder under the root is mounted"
for skipped in "$BIN_GUID" "$MD_GUID" "$UNUSED_GUID" "abc-123" "usersecrets/other"; do
    if grep -qF -- "$skipped" "$LOG"; then fail "--secrets must not mount '$skipped' (got: $(cat "$LOG"))"; else pass; fi
done
unset TEST_HOME

echo ""
echo "Passed: $PASS_COUNT, Failed: $FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
