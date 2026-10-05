## MODIFIED Requirements

### Requirement: Workspace folder can be overridden at runtime
`claude-yolo` SHALL accept a workspace-path override in either of two forms, given before the subcommand: the explicit `--workspace <path>` option, or a bare positional argument that is not `--help`/`-h`, not `--workspace`, and not a recognized subcommand keyword (`rebuild`, `nuke`, `run`, `yolo`). Either form mounts `<path>` as `/workspace` inside the container instead of the script's default parent directory. A subcommand keyword SHALL always be recognized as a subcommand, never as a workspace path.

#### Scenario: Explicit workspace path
- **WHEN** `claude-yolo --workspace /some/other/project run -- "task"` is invoked
- **THEN** `/some/other/project` SHALL be mounted as `/workspace` inside the container, rather than the script's default parent directory

#### Scenario: Bare positional workspace path
- **WHEN** `claude-yolo /some/other/project run -- "task"` is invoked
- **THEN** `/some/other/project` SHALL be mounted as `/workspace` inside the container, the same as `claude-yolo --workspace /some/other/project run -- "task"` would

#### Scenario: Explicit workspace path with the no-args default (yolo mode)
- **WHEN** `claude-yolo --workspace /some/other/project -- "task"` is invoked
- **THEN** `/some/other/project` SHALL be mounted as `/workspace`, and `claude --dangerously-skip-permissions "task"` SHALL run against it, the same as `claude-yolo --workspace /some/other/project yolo -- "task"` would

#### Scenario: Subcommand keyword as workspace folder name is not ambiguous
- **WHEN** a directory happens to be named `run` (or `yolo`, `rebuild`, `nuke`) and `claude-yolo run` is invoked from a context where that directory could be meant
- **THEN** `run` SHALL be treated as the subcommand, not as a workspace path
- **AND** mounting such a directory as the workspace SHALL require an explicit path form such as `./run` or `--workspace run`

### Requirement: Invalid workspace path fails clearly before launching a container
If the path given via `--workspace` or the bare positional form does not exist or is not a directory, `claude-yolo` SHALL fail with a clear error and SHALL NOT start a container.

#### Scenario: Nonexistent path
- **WHEN** `claude-yolo --workspace /no/such/folder run` is invoked and `/no/such/folder` does not exist
- **THEN** the script SHALL exit with an error identifying the invalid workspace path
- **AND** no container SHALL be started

#### Scenario: Nonexistent path via bare positional form
- **WHEN** `claude-yolo /no/such/folder run` is invoked and `/no/such/folder` does not exist
- **THEN** the script SHALL exit with an error identifying the invalid workspace path
- **AND** no container SHALL be started
