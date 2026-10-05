## Context

See proposal.md - Why. The Dockerfile currently has three version pins installed in one `npm install -g` step: `CLAUDE_VERSION`, `OPENSPEC_VERSION`, `OPENCODE_VERSION`. `DISABLE_AUTOUPDATER=1` exists solely to stop Claude Code's own background updater from drifting away from whichever version the build installed.

## Goals / Non-Goals

**Goals:**
- Every image build installs whatever Claude Code release is newest on npm at that moment.
- A running container's Claude Code version never changes on its own.

**Non-Goals:**
- Changing how `openspec` or `opencode-ai` are versioned — they stay pinned via `OPENSPEC_VERSION` / `OPENCODE_VERSION`. The request was specifically about Claude Code.
- Reproducible builds for Claude Code's version. This change deliberately trades that away for freshness.

## Decisions

- **Install `@anthropic-ai/claude-code@latest` in place of `@anthropic-ai/claude-code@${CLAUDE_VERSION}`**, and delete the `ARG CLAUDE_VERSION=...` line entirely, rather than keeping the ARG as a default and overriding it with a separate update step. One install line is simpler than pin-then-update, and there's no remaining caller that needs the ARG once nothing defaults to it.
- **Keep `DISABLE_AUTOUPDATER=1`.** Its job changes (previously: protect an exact pin; now: protect whatever `latest` resolved to at build time) but the requirement — the installed version must not change inside a running container — still holds, so the setting stays.
- **Only Claude Code floats.** `openspec` and `opencode-ai` keep their explicit version ARGs; the user's request was scoped to Claude Code, and floating the others wasn't asked for.

## Risks / Trade-offs

- [Two builds taken at different times install different Claude Code versions, so a bug report can't be reproduced by rebuilding later] → Accepted: this is the explicit goal (always current over reproducible). If this bites in practice, the image could print the resolved version during build so it's visible after the fact.
- [`npm install -g ...@latest` can pick up a release with a breaking change with no warning] → No mitigation in this change; same exposure the already-unpinned `dotnet-stryker` install has.
