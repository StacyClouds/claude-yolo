# workspace-selection Specification

## Purpose

Lets the caller choose which host folder is mounted as `/workspace` at runtime, instead of it always being the `claude-yolo` script's own parent directory, without needing an image rebuild.

## Requirements

### Requirement: Workspace folder can be overridden at runtime
`claude-yolo` SHALL accept a `--workspace <path>` option, given before the subcommand, that mounts `<path>` as `/workspace` inside the container instead of the script's default parent directory.

#### Scenario: Explicit workspace path
- **WHEN** `claude-yolo --workspace /some/other/project run "task"` is invoked
- **THEN** `/some/other/project` SHALL be mounted as `/workspace` inside the container, rather than the script's default parent directory

#### Scenario: Explicit workspace path with the no-args default (yolo mode)
- **WHEN** `claude-yolo --workspace /some/other/project "task"` is invoked
- **THEN** `/some/other/project` SHALL be mounted as `/workspace`, and `claude --dangerously-skip-permissions "task"` SHALL run against it, the same as `claude-yolo --workspace /some/other/project yolo "task"` would

### Requirement: Default workspace is unchanged when not overridden
When `--workspace` is not given, `claude-yolo` SHALL mount the script's parent directory as `/workspace`, exactly as it does today.

#### Scenario: No --workspace given
- **WHEN** `claude-yolo run` (or any existing invocation form) is used without `--workspace`
- **THEN** the script's parent directory SHALL be mounted as `/workspace`, unchanged from current behavior

### Requirement: Invalid workspace path fails clearly before launching a container
If the path given to `--workspace` does not exist or is not a directory, `claude-yolo` SHALL fail with a clear error and SHALL NOT start a container.

#### Scenario: Nonexistent path
- **WHEN** `claude-yolo --workspace /no/such/folder run` is invoked and `/no/such/folder` does not exist
- **THEN** the script SHALL exit with an error identifying the invalid workspace path
- **AND** no container SHALL be started

### Requirement: Concurrent invocations with different workspaces run independently
Running `claude-yolo` more than once at the same time with different `--workspace` paths SHALL produce independent containers, each mounting its own specified folder as `/workspace`, while continuing to share the same persisted `claude-yolo-home` login/session volume.

#### Scenario: Two concurrent invocations, different workspaces
- **WHEN** `claude-yolo --workspace /project-a run` and `claude-yolo --workspace /project-b run` are invoked at the same time
- **THEN** each SHALL run in its own container with `/workspace` mounted to its respective folder
- **AND** both SHALL share the same `claude-yolo-home` volume for Claude's login/session state
