#!/bin/sh
# Checks on the host-services skill and its packaging (see
# openspec/changes/add-host-services-skill). The image is not built here.
#
# Usage: sh test/host-services-skill.test.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$SCRIPT_DIR/skills/host-services/SKILL.md"

PASS=0
FAIL=0
check() {
    # check <message> <command...>
    msg="$1"
    shift
    if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $msg"; fi
}

check "skill file exists" test -f "$SKILL"
check "front matter opens the file" sh -c "head -n1 '$SKILL' | grep -qx -- '---'"
check "front matter has name: host-services" grep -qx 'name: host-services' "$SKILL"
check "front matter has a description" grep -qE '^description: .{40,}' "$SKILL"
check "mentions host.docker.internal" grep -q 'host.docker.internal' "$SKILL"
check "documents a port probe" grep -q '/dev/tcp/host.docker.internal' "$SKILL"
for port in 10000 10001 10002 8081; do
    check "documents port $port" grep -q "host.docker.internal:$port" "$SKILL"
done
check "says host containers must publish ports" grep -qi 'publish' "$SKILL"
check "Dockerfile copies the skill to /opt/skills/host-services" \
    grep -qE '^COPY .*skills/host-services.* /opt/skills/host-services' "$SCRIPT_DIR/Dockerfile"
check ".dockerignore lets skills/ into the build context" grep -qx '!skills/\*\*' "$SCRIPT_DIR/.dockerignore"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
