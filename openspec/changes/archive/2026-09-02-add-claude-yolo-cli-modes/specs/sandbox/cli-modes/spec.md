## Purpose

Defines the command-line modes of the `claude-yolo` run script — how to launch the sandbox in YOLO mode or with normal permissions, force a rebuild, or reset it entirely — instead of a single fixed build-and-run behavior.

## ADDED Requirements

### Requirement: YOLO mode is the default and an explicit subcommand
Running `claude-yolo` with no subcommand SHALL behave identically to running `claude-yolo yolo`: it SHALL ensure the sandbox image exists and then launch `claude --dangerously-skip-permissions` inside it.

#### Scenario: No-args invocation launches YOLO mode
- **WHEN** `claude-yolo` is invoked with no subcommand
- **THEN** it SHALL launch `claude` with `--dangerously-skip-permissions` inside the sandbox, the same as `claude-yolo yolo` would

#### Scenario: Explicit yolo subcommand
- **WHEN** `claude-yolo yolo` is invoked
- **THEN** it SHALL launch `claude` with `--dangerously-skip-permissions` inside the sandbox

### Requirement: run mode launches Claude with normal permissions
`claude-yolo run` SHALL ensure the sandbox image exists and then launch `claude` inside it without `--dangerously-skip-permissions`, so Claude's normal permission prompts apply.

#### Scenario: run launches Claude without skipping permissions
- **WHEN** `claude-yolo run` is invoked
- **THEN** it SHALL launch `claude` inside the sandbox without the `--dangerously-skip-permissions` flag

### Requirement: run and yolo build the image only when it doesn't already exist
Both `run` and `yolo` (including the no-args default) SHALL build the sandbox image automatically when it does not already exist, and SHALL reuse the existing image without rebuilding when it does.

#### Scenario: First invocation with no existing image
- **WHEN** `claude-yolo run` or `claude-yolo yolo` is invoked and no `claude-yolo` image exists yet
- **THEN** the image SHALL be built before the container is launched

#### Scenario: Subsequent invocation with an existing image
- **WHEN** `claude-yolo run` or `claude-yolo yolo` is invoked and a `claude-yolo` image already exists
- **THEN** the existing image SHALL be reused and no build SHALL be performed

### Requirement: rebuild forces a fresh image build without launching a container
`claude-yolo rebuild` SHALL force a fresh build of the sandbox image, bypassing build cache reuse of the kind that would otherwise skip picking up updated Dockerfile content or newer versions of floating dependencies, and SHALL exit without launching a container.

#### Scenario: rebuild refreshes an already-existing image
- **WHEN** `claude-yolo rebuild` is invoked and a `claude-yolo` image already exists
- **THEN** a fresh build SHALL run rather than reusing the existing image unchanged

#### Scenario: rebuild does not start the sandbox
- **WHEN** `claude-yolo rebuild` completes
- **THEN** no container SHALL be started as part of that invocation

### Requirement: nuke resets the sandbox image and persisted login
`claude-yolo nuke` SHALL remove the built sandbox image and the persisted `claude-yolo-home` volume (which holds Claude's login/auth state), and SHALL ask for confirmation before doing so, since this deletes local state that cannot be recovered automatically.

#### Scenario: nuke removes the image and the persisted volume
- **WHEN** `claude-yolo nuke` is invoked and confirmed
- **THEN** the sandbox image SHALL be removed
- **AND** the `claude-yolo-home` volume SHALL be removed

#### Scenario: nuke requires confirmation
- **WHEN** `claude-yolo nuke` is invoked
- **THEN** it SHALL prompt for confirmation before removing anything
- **AND** declining the prompt SHALL leave the image and volume untouched

### Requirement: extra arguments pass through to the Claude invocation
Arguments given after the subcommand (or after `claude-yolo` itself when no subcommand is given) SHALL be forwarded to the `claude` invocation inside the container, for both `run` and `yolo` modes.

#### Scenario: Arguments after an explicit subcommand
- **WHEN** `claude-yolo run "review this file"` is invoked
- **THEN** `"review this file"` SHALL be passed through to the `claude` command inside the container

#### Scenario: Arguments after the no-args default
- **WHEN** `claude-yolo "fix the bug"` is invoked
- **THEN** `"fix the bug"` SHALL be passed through to the `claude` command inside the container, the same as `claude-yolo yolo "fix the bug"` would
