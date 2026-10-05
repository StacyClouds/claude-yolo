#!/bin/sh
# Entrypoint for the opencode-yolo sandbox (see openspec/changes/add-opencode-yolo).
# Used only via `docker run --entrypoint opencode-entrypoint.sh` from the
# opencode-yolo script - claude-yolo never invokes this file. Unlike
# entrypoint.sh (Claude-specific host-config sync, trust dialog, serena
# rewiring), this script's only job is wiring opencode up to a local
# OpenAI-compatible model server before handing off to the requested command.
#
# On every container start: probe $MLX_BASE_URL/v1/models (default
# http://host.docker.internal:8000, reachable via the opencode-yolo script's
# --add-host=host.docker.internal:host-gateway) for the model currently
# loaded there, and merge an opencode provider pointing at it - plus that
# model as the default - into the persisted global opencode.json, so the
# user never has to name a model themselves. If the server isn't reachable
# yet, warn and continue rather than blocking the sandbox from starting.
set -eu

MLX_BASE_URL="${MLX_BASE_URL:-http://host.docker.internal:8000}"
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG="$OPENCODE_CONFIG_DIR/opencode.json"

# -fsS: fail on HTTP errors, silent otherwise but still print real errors.
# --max-time: the model server may simply not be running yet; don't hang
# container startup waiting on it.
MODELS_RESPONSE="$(curl -fsS --max-time 3 "$MLX_BASE_URL/v1/models" 2>/dev/null || true)"

MODEL_ID=""
if [ -n "$MODELS_RESPONSE" ]; then
    MODEL_ID="$(printf '%s' "$MODELS_RESPONSE" | jq -r '.data[0].id // empty' 2>/dev/null || true)"
fi

if [ -n "$MODEL_ID" ]; then
    mkdir -p "$OPENCODE_CONFIG_DIR"
    [ -f "$OPENCODE_CONFIG" ] || echo '{}' > "$OPENCODE_CONFIG"

    # Merge, not overwrite: anything else the user has added to this file
    # inside a previous running container (other providers, permission
    # overrides, ...) survives on the persisted opencode-yolo-home volume.
    # apiKey is a fixed placeholder, not a secret: the openai-compatible
    # provider shape requires the field, but a local MLX server doesn't
    # check it. autoupdate is disabled so opencode's own updater can't
    # drift the image away from the OPENCODE_VERSION pinned in the
    # Dockerfile, mirroring DISABLE_AUTOUPDATER for Claude Code there.
    jq \
        --arg baseURL "$MLX_BASE_URL/v1" \
        --arg apiKey "not-needed" \
        --arg id "$MODEL_ID" \
        '.provider.mlx = {
            npm: "@ai-sdk/openai-compatible",
            name: "Local MLX",
            options: {baseURL: $baseURL, apiKey: $apiKey},
            models: {($id): {}}
        }
        | .model = ("mlx/" + $id)
        | .autoupdate = false' \
        "$OPENCODE_CONFIG" > "$OPENCODE_CONFIG.tmp"
    mv "$OPENCODE_CONFIG.tmp" "$OPENCODE_CONFIG"
else
    printf 'opencode-entrypoint: could not reach a model at %s/v1/models - opencode will start with no default model configured.\nStart your local model server and restart the container to pick it up.\n' "$MLX_BASE_URL" >&2
fi

exec tini -- "$@"
