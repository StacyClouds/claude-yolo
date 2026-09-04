## Purpose

Gives Claude Code inside the sandbox access to the host user's `~/.claude` configuration (settings, agents, skills, plugins, commands) via a read-only, run-time mount, so the sandbox behaves like the user's own global Claude Code setup instead of a separately maintained, build-time-baked one — without sacrificing the sandbox's own persisted login/session state.

## ADDED Requirements

### Requirement: Host's ~/.claude config is available inside the sandbox
When the host has a directory at `~/.claude`, the sandbox SHALL make its config items (`CLAUDE.md`, `settings.json`, `settings.local.json`, `agents`, `commands`, `skills`, `plugins`, `rules`, `keybindings.json`, `statusline-command.sh`, `statusline-command.ps1`, `workflows`) available to Claude Code inside the container at its global configuration path, refreshed on every container start.

#### Scenario: Host ~/.claude present
- **WHEN** the host has a directory at `~/.claude` and `claude-yolo run` or `claude-yolo yolo` is invoked
- **THEN** those config items SHALL be readable by Claude Code inside the container at its global configuration path

### Requirement: Login and other sandbox-local runtime state persists across runs
The sandbox's own runtime state under its global configuration path — including login credentials, session/conversation history, project trust decisions, shell snapshots, and todos — SHALL persist across container runs on the `claude-yolo-home` volume, and SHALL NOT be overwritten or removed by the host `~/.claude` config sync. This state SHALL only be removed by `claude-yolo nuke`.

#### Scenario: Container closed and a new one started
- **WHEN** Claude Code has logged in (or otherwise written runtime state) inside a `claude-yolo` container, and that container is closed
- **THEN** a subsequent `claude-yolo run` or `claude-yolo yolo` invocation SHALL still be logged in, without needing to log in again

#### Scenario: Host config synced on top of existing runtime state
- **WHEN** a container starts with both a mounted host `~/.claude` and pre-existing runtime state (e.g. login credentials) on the `claude-yolo-home` volume
- **THEN** the host's config items SHALL be applied
- **AND** the pre-existing runtime state SHALL remain unchanged

#### Scenario: Nuke removes persisted login
- **WHEN** `claude-yolo nuke` is run and confirmed
- **THEN** the `claude-yolo-home` volume (including any persisted login/session state) SHALL be removed

### Requirement: The bypass-permissions confirmation stays accepted across runs
The sandbox SHALL start with Claude Code's "Bypass Permissions mode" confirmation dialog already accepted, and the host config sync SHALL NOT cause that acceptance to be lost on a later run.

#### Scenario: Fresh container with a host ~/.claude mounted
- **WHEN** `claude-yolo yolo` is invoked, and the host's `~/.claude/settings.json` does not itself accept bypass permissions mode
- **THEN** Claude Code inside the container SHALL start in bypass-permissions mode without showing the confirmation dialog

#### Scenario: Repeated runs
- **WHEN** `claude-yolo yolo` is run again in a later, separate container
- **THEN** the confirmation dialog SHALL still not appear, regardless of what was accepted or not accepted in a previous container's life

#### Scenario: No host ~/.claude folder
- **WHEN** the host has no `~/.claude` folder and `claude-yolo yolo` is invoked
- **THEN** the confirmation dialog SHALL still not appear

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
