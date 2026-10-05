## MODIFIED Requirements

### Requirement: extra arguments pass through to the Claude invocation
Arguments meant for the `claude` invocation inside the container (for `run` and `yolo` modes, including the no-args default) SHALL be given after a literal `--` separator. Everything after that `--` SHALL be forwarded to `claude` verbatim, however it is itself formed (including further `-`-prefixed flags).

#### Scenario: Arguments after an explicit subcommand
- **WHEN** `claude-yolo run -- "review this file"` is invoked
- **THEN** `"review this file"` SHALL be passed through to the `claude` command inside the container

#### Scenario: Arguments after the no-args default
- **WHEN** `claude-yolo -- "fix the bug"` is invoked
- **THEN** `"fix the bug"` SHALL be passed through to the `claude` command inside the container, the same as `claude-yolo yolo -- "fix the bug"` would

#### Scenario: Claude's own flags pass through unchanged
- **WHEN** `claude-yolo run -- --model opus -p "one-shot query"` is invoked
- **THEN** `--model opus -p "one-shot query"` SHALL be passed through to the `claude` command inside the container exactly as given, without `claude-yolo` itself interpreting any of those flags

### Requirement: An unrecognized leftover argument is a hard error
After workspace-path and subcommand resolution, if any argument remains that is not a literal `--`, `claude-yolo` SHALL exit with an error explaining that `--` is required before arguments meant for `claude`, and SHALL NOT start a container.

#### Scenario: Prompt text given without the -- separator
- **WHEN** `claude-yolo run "review this file"` is invoked (no `--` before the prompt text)
- **THEN** the script SHALL exit with an error naming the unexpected argument and mentioning the `--` separator
- **AND** no container SHALL be started

#### Scenario: No-args default without the -- separator
- **WHEN** `claude-yolo "fix the bug"` is invoked (no subcommand, no `--` before the prompt text)
- **THEN** the script SHALL exit with an error, since `"fix the bug"` does not resolve to an existing directory to use as the workspace and is not a recognized subcommand
- **AND** that error SHALL mention the `--` separator as how to pass the text through to `claude` instead
- **AND** no container SHALL be started
