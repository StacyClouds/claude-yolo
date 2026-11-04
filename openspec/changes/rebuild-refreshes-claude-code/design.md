## Context

`claude-yolo` builds with `docker build -t "$IMAGE" "$SCRIPT_DIR"` for both the automatic first build and `rebuild`. The `npm install -g` step lists `claude-code@latest`; its instruction text never changes, so the cached layer is reused indefinitely.

## Goals / Non-Goals

**Goals:**
- `rebuild` always installs the newest Claude Code release.
- Keep the slow early layers (apt packages, Serena builder) cached.

**Non-Goals:**
- Refreshing Claude Code on first-time builds (nothing is cached).
- Pinning versions.

## Decisions

**Cache-busting build argument, supplied only by `rebuild`.** The `Dockerfile` declares `ARG CLAUDE_CODE_CACHE_BUST=` immediately before the install step. A different value invalidates that layer and all later ones. `rebuild` passes the current Unix time. Alternative considered: `--no-cache`, which also rebuilds the Serena builder stage and all apt layers for no benefit; rejected as needlessly slow.

**`--pull` on `rebuild`.** Refreshes the `node:22-bookworm-slim` base so security updates arrive, matching the intent of "force a fresh build".

**`build_image` takes extra arguments.** The automatic build path calls it with none, so its behaviour is unchanged.
