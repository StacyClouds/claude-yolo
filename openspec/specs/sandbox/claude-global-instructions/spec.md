## Purpose

Gives Claude running inside the sandbox access to the host user's global `CLAUDE.md`, kept current via a run-time mount instead of a build-time copy.

## Requirements

### Requirement: Host's global CLAUDE.md is available inside the sandbox
When the host has a global `CLAUDE.md` (at `~/.claude/CLAUDE.md`), the sandbox SHALL make it available to Claude Code at its global-instructions path inside the container.

#### Scenario: Global CLAUDE.md present on host
- **WHEN** the host has a file at `~/.claude/CLAUDE.md` and `claude-yolo run` or `claude-yolo yolo` is invoked
- **THEN** that file's content SHALL be readable by Claude Code inside the container at its global-instructions path

### Requirement: The mount always reflects the current host file
The sandbox SHALL NOT bake a copy of the global `CLAUDE.md` into the built image; it SHALL be supplied at container run time so edits to the host file take effect on the next run without rebuilding the image.

#### Scenario: Host file edited between runs
- **WHEN** the host's `~/.claude/CLAUDE.md` is edited after the sandbox image was last built
- **THEN** the next `claude-yolo run` or `claude-yolo yolo` invocation SHALL see the edited content, without requiring `claude-yolo rebuild`

### Requirement: Claude cannot modify the host's copy from inside the sandbox
The global `CLAUDE.md` SHALL be exposed to the container read-only.

#### Scenario: Attempted write from inside the container
- **WHEN** a process inside the container attempts to write to the global `CLAUDE.md` path
- **THEN** the write SHALL fail, and the host's file SHALL remain unchanged

### Requirement: Missing host file does not break the sandbox
If the host has no global `CLAUDE.md`, `claude-yolo run` and `claude-yolo yolo` SHALL still start normally, simply without a global `CLAUDE.md` available inside the container.

#### Scenario: No global CLAUDE.md on host
- **WHEN** the host has no file at `~/.claude/CLAUDE.md` and `claude-yolo run` or `claude-yolo yolo` is invoked
- **THEN** the sandbox SHALL start normally without error
