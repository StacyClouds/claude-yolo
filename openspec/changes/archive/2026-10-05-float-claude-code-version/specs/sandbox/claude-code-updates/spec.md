## Purpose

Defines how the sandbox image keeps the bundled Claude Code CLI current: resolved to the latest release at build time, then held fixed for the life of a running container.

## ADDED Requirements

### Requirement: Image build installs the latest Claude Code release
The sandbox image build SHALL install the latest available `@anthropic-ai/claude-code` release from npm, rather than a pinned version number.

#### Scenario: Building the image
- **WHEN** the sandbox image is built
- **THEN** the `npm install -g` step SHALL resolve and install the newest `@anthropic-ai/claude-code` release available on npm at that time

### Requirement: Running containers never auto-update Claude Code
Once a container is running, Claude Code's own background auto-updater SHALL remain disabled, so the version installed at build time does not change while the container is in use.

#### Scenario: Claude Code running inside a container
- **WHEN** Claude Code runs inside a started container
- **THEN** it SHALL NOT check for or install an update in the background
- **AND** the installed version SHALL remain the one resolved at build time until the image is rebuilt
