## 1. Dockerfile changes

- [x] 1.1 Remove the `ARG CLAUDE_VERSION=2.1.258` line and verify no remaining reference to `CLAUDE_VERSION` exists in the Dockerfile (`grep -n CLAUDE_VERSION Dockerfile` returns nothing)
- [x] 1.2 Change the `npm install -g` step's Claude Code line from `@anthropic-ai/claude-code@${CLAUDE_VERSION}` to `@anthropic-ai/claude-code@latest`, leaving the `@fission-ai/openspec@${OPENSPEC_VERSION}` and `opencode-ai@${OPENCODE_VERSION}` lines pinned as-is
- [x] 1.3 Update the comment above `ENV DISABLE_AUTOUPDATER=1` to describe the new rationale (build always installs latest; the setting now stops that build-time version from drifting at runtime instead of protecting an exact pin)

## 2. Verification

- [x] 2.1 Build the image (`docker build -t claude-yolo .`) and verify it completes successfully with no reference to the removed `CLAUDE_VERSION` arg
- [x] 2.2 Run `claude --version` inside a container started from the built image and verify it reports a current release (compare against npm's published `latest` tag for `@anthropic-ai/claude-code` at build time)
- [x] 2.3 Confirm `DISABLE_AUTOUPDATER` is still set inside the running container (e.g. `docker run --rm claude-yolo env | grep DISABLE_AUTOUPDATER`) so the installed version does not change at runtime
