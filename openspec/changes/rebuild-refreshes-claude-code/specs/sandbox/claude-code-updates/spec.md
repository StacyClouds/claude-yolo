## ADDED Requirements

### Requirement: Rebuild installs the latest Claude Code release despite cached layers
`claude-yolo rebuild` SHALL cause the Claude Code install step to run again, so the rebuilt image contains the newest `@anthropic-ai/claude-code` release regardless of which earlier build layers are cached. It SHALL also refresh the base image.

#### Scenario: Rebuilding with a warm layer cache
- **WHEN** the user runs `claude-yolo rebuild` and a previous build's layers are cached
- **THEN** the `docker build` call SHALL include a `CLAUDE_CODE_CACHE_BUST` build argument whose value differs from the previous rebuild
- **AND** the `docker build` call SHALL include `--pull`

#### Scenario: First-time build when the image is missing
- **WHEN** the user runs `claude-yolo` or `claude-yolo run` and no image exists
- **THEN** the image SHALL be built without the cache-busting argument
