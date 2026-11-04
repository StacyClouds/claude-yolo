#!/bin/sh
# Text checks on the Dockerfile (see openspec/changes/add-procps-tools).
# The image is not built here; building is checked manually.
#
# Usage: sh test/dockerfile.test.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCKERFILE="$SCRIPT_DIR/Dockerfile"

# The final stage is everything after the last FROM line.
final_stage="$(awk '/^FROM /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$DOCKERFILE" | sed ':a;/\\$/{N;s/\\\n/ /;ba}')"

if printf '%s' "$final_stage" | grep -qE "apt-get install [^&]* procps( |$)"; then
    echo "1 passed, 0 failed"
else
    echo "FAIL: final stage must apt-get install procps"
    echo "0 passed, 1 failed"
    exit 1
fi
