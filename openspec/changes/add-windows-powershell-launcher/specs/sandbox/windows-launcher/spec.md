## Purpose

Provides a PowerShell entry point (`claude-yolo.ps1`) so the claude-yolo sandbox can be built and launched from `cmd.exe`/PowerShell on Windows, matching the `sh` script's CLI modes and workspace selection without requiring WSL or Git Bash.

## ADDED Requirements

### Requirement: PowerShell script supports the same subcommands as the sh script
`claude-yolo.ps1` SHALL support the same subcommands as `claude-yolo`, with the same defaults: no subcommand behaves as `yolo`, `run` launches `claude` with normal permission prompts, `rebuild` forces a fresh image build without launching a container, and `nuke` removes the image and persisted volume after confirmation.

#### Scenario: No-args invocation launches YOLO mode
- **WHEN** `claude-yolo.ps1` is invoked with no subcommand
- **THEN** it SHALL ensure the sandbox image exists and launch `claude --dangerously-skip-permissions` inside it, the same as `claude-yolo.ps1 yolo` would

#### Scenario: run launches Claude with normal permissions
- **WHEN** `claude-yolo.ps1 run` is invoked
- **THEN** it SHALL ensure the sandbox image exists and launch `claude` inside it without `--dangerously-skip-permissions`

#### Scenario: rebuild forces a fresh build without launching a container
- **WHEN** `claude-yolo.ps1 rebuild` is invoked
- **THEN** a fresh `docker build` SHALL run regardless of whether the image already exists
- **AND** no container SHALL be started as part of that invocation

### Requirement: Extra arguments pass through to the Claude invocation
Arguments given after the subcommand (or after `claude-yolo.ps1` itself when no subcommand is given) SHALL be forwarded unchanged to the `claude` invocation inside the container, for both `run` and `yolo` modes.

#### Scenario: Arguments after an explicit subcommand
- **WHEN** `claude-yolo.ps1 run "review this file"` is invoked
- **THEN** `"review this file"` SHALL be passed through to the `claude` command inside the container

#### Scenario: Arguments after the no-args default
- **WHEN** `claude-yolo.ps1 "fix the bug"` is invoked
- **THEN** `"fix the bug"` SHALL be passed through to the `claude` command inside the container, the same as `claude-yolo.ps1 yolo "fix the bug"` would

### Requirement: --workspace overrides the mounted project folder
`claude-yolo.ps1` SHALL accept a `--workspace <path>` option, given before the subcommand, that mounts `<path>` as `/workspace` inside the container instead of the script's own parent directory. If the path does not exist or is not a directory, the script SHALL fail with a clear error before starting any container.

#### Scenario: Explicit workspace path
- **WHEN** `claude-yolo.ps1 --workspace C:\code\some-other-project run "task"` is invoked
- **THEN** `C:\code\some-other-project` SHALL be mounted as `/workspace` inside the container, rather than the script's default parent directory

#### Scenario: Nonexistent workspace path
- **WHEN** `claude-yolo.ps1 --workspace C:\no\such\folder run` is invoked and that path does not exist
- **THEN** the script SHALL exit with an error identifying the invalid workspace path
- **AND** no container SHALL be started

### Requirement: nuke removes the image and persisted volume after confirmation
`claude-yolo.ps1 nuke` SHALL prompt for confirmation, then remove the sandbox image and the persisted `claude-yolo-home` volume when confirmed, and leave both untouched when declined. `claude-yolo.ps1 nuke --preserve-token` SHALL instead empty the volume while preserving `~/.claude/.credentials.json`, matching the `sh` script's behavior.

#### Scenario: nuke removes the image and volume when confirmed
- **WHEN** `claude-yolo.ps1 nuke` is invoked and the confirmation prompt is accepted
- **THEN** the sandbox image SHALL be removed
- **AND** the `claude-yolo-home` volume SHALL be removed

#### Scenario: nuke leaves state untouched when declined
- **WHEN** `claude-yolo.ps1 nuke` is invoked and the confirmation prompt is declined
- **THEN** the sandbox image and the `claude-yolo-home` volume SHALL remain unchanged

#### Scenario: nuke --preserve-token keeps the login credential
- **WHEN** `claude-yolo.ps1 nuke --preserve-token` is invoked and confirmed
- **THEN** the sandbox image SHALL be removed
- **AND** the `claude-yolo-home` volume SHALL be emptied except for `~/.claude/.credentials.json`

### Requirement: Host Claude config is mounted from the Windows user profile
When the invoking user has a `.claude` folder under their Windows user profile directory, `claude-yolo.ps1` SHALL mount it read-only into the container at `/home/node/.claude-host`, the same way the `sh` script mounts `$HOME/.claude`. When no such folder exists, the script SHALL start the container without that mount rather than failing.

#### Scenario: Host config folder present
- **WHEN** the invoking user has a `.claude` folder under their Windows user profile directory
- **THEN** it SHALL be mounted read-only at `/home/node/.claude-host` inside the container

#### Scenario: No host config folder
- **WHEN** the invoking user has no `.claude` folder under their Windows user profile directory
- **THEN** the container SHALL still start, without that mount

### Requirement: Image and volume are shared with the sh script
`claude-yolo.ps1` SHALL use the same Docker image name (`claude-yolo`) and the same named volume (`claude-yolo-home`) as `claude-yolo`, so a sandbox built or logged into from one script is reused by the other on a machine where both are available.

#### Scenario: Image built by the sh script is reused by the PowerShell script
- **WHEN** the `claude-yolo` image already exists (for example, built previously via the `sh` script under WSL) and `claude-yolo.ps1 run` is invoked
- **THEN** the existing image SHALL be reused and no build SHALL be performed

#### Scenario: Login persists across both scripts
- **WHEN** a user has an active login recorded in the `claude-yolo-home` volume from a session started via one script
- **THEN** a session started via the other script SHALL reuse that same login without prompting again
