## Purpose

Gives Claude Code inside the sandbox access to the host user's full `~/.claude` configuration (settings, agents, skills, plugins, commands) via a read-only, run-time mount, so the sandbox behaves like the user's own global Claude Code setup instead of a separately maintained, build-time-baked one.

## ADDED Requirements

### Requirement: Host's ~/.claude folder is available inside the sandbox
When the host has a directory at `~/.claude`, the sandbox SHALL make its full contents (settings, agents, skills, plugins, commands, `CLAUDE.md`, etc.) available to Claude Code inside the container at its global configuration path.

#### Scenario: Host ~/.claude present
- **WHEN** the host has a directory at `~/.claude` and `claude-yolo run` or `claude-yolo yolo` is invoked
- **THEN** that directory's contents SHALL be readable by Claude Code inside the container at its global configuration path

### Requirement: The mount always reflects the current host folder
The sandbox SHALL NOT bake a copy of the host's `~/.claude` folder into the built image; it SHALL be supplied at container run time so edits to the host folder take effect on the next run without rebuilding the image.

#### Scenario: Host folder edited between runs
- **WHEN** the host's `~/.claude` folder is edited (a setting changed, an agent, skill, or plugin added or removed) after the sandbox image was last built
- **THEN** the next `claude-yolo run` or `claude-yolo yolo` invocation SHALL see the edited content, without requiring `claude-yolo rebuild`

### Requirement: Claude cannot modify the host's copy from inside the sandbox
The host `~/.claude` folder SHALL be exposed to the container read-only.

#### Scenario: Attempted write from inside the container
- **WHEN** a process inside the container attempts to write to any path under the mounted `~/.claude` folder
- **THEN** the write SHALL fail, and the host's folder SHALL remain unchanged

### Requirement: Missing host folder does not break the sandbox
If the host has no `~/.claude` folder, `claude-yolo run` and `claude-yolo yolo` SHALL still start normally, without any settings, agents, skills, or plugins sourced from the host.

#### Scenario: No host ~/.claude folder
- **WHEN** the host has no directory at `~/.claude` and `claude-yolo run` or `claude-yolo yolo` is invoked
- **THEN** the sandbox SHALL start normally without error
- **AND** no host settings, agents, skills, or plugins SHALL be available inside the container
