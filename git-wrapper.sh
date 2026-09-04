#!/bin/sh
# Installed as /usr/local/bin/git (see Dockerfile), shadowing the real binary
# at /usr/bin/git on PATH. Blocks `push` and its plumbing equivalent
# `send-pack` - to any remote, however invoked, not just one named `origin` -
# and delegates every other subcommand to the real binary unchanged. See
# openspec/changes/add-restricted-git for the full rationale.
set -eu

REAL_GIT=/usr/bin/git

# Find the actual subcommand by skipping git's own value-taking global
# options (-C <path>, -c <name>=<value>); every other `-`-prefixed token
# (e.g. --git-dir=<path>, which embeds its value after `=`) is skipped as-is.
subcommand=""
skip_next=0
for arg in "$@"; do
    if [ "$skip_next" = 1 ]; then
        skip_next=0
        continue
    fi
    case "$arg" in
        -C|-c)
            skip_next=1
            continue
            ;;
        -*)
            continue
            ;;
        *)
            subcommand="$arg"
            break
            ;;
    esac
done

case "$subcommand" in
    push|send-pack)
        printf 'git %s is disabled in this sandbox (claude-yolo container) - commits stay local; push happens on the host.\n' "$subcommand" >&2
        exit 1
        ;;
esac

exec "$REAL_GIT" "$@"
