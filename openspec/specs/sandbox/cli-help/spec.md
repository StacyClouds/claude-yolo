# cli-help Specification

## Purpose

Lets a caller discover `claude-yolo`'s usage, subcommands, and argument grammar at the command line, instead of needing to read the script's source.

## Requirements

### Requirement: --help and -h print usage and exit without side effects
`claude-yolo --help` and `claude-yolo -h` SHALL print usage information (subcommands, the workspace-override form, and the `--` argument-forwarding convention) and exit with status 0, without building an image, starting a container, or requiring Docker to be available.

#### Scenario: --help prints usage and exits cleanly
- **WHEN** `claude-yolo --help` is invoked
- **THEN** usage information SHALL be printed
- **AND** the script SHALL exit with status 0
- **AND** no Docker image build or container run SHALL be attempted

#### Scenario: -h behaves the same as --help
- **WHEN** `claude-yolo -h` is invoked
- **THEN** it SHALL behave identically to `claude-yolo --help`

#### Scenario: --help takes priority over other arguments
- **WHEN** `claude-yolo --help` is invoked alongside any other arguments (e.g. `claude-yolo --help run`)
- **THEN** usage information SHALL be printed and the script SHALL exit with status 0 without processing the other arguments
