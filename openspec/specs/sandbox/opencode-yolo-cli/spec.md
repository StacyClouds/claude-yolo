# opencode-yolo-cli Specification

## Purpose

Defines the command-line modes of a new `opencode-yolo` run script — a sibling to `claude-yolo` that launches `opencode` instead of `claude` inside the same sandbox isolation model (restricted `git push`, no host credentials, `/workspace` bind mount), with its own image tag and persisted home volume so it never shares build or reset state with `claude-yolo`.

## Requirements

### Requirement: YOLO mode is the default and an explicit subcommand
Running `opencode-yolo` with no subcommand SHALL behave identically to running `opencode-yolo yolo`: it SHALL ensure the `opencode-yolo` sandbox image exists and then launch `opencode --auto` inside it.

#### Scenario: No-args invocation launches auto-approve mode
- **WHEN** `opencode-yolo` is invoked with no subcommand
- **THEN** it SHALL launch `opencode` with `--auto` inside the sandbox, the same as `opencode-yolo yolo` would

#### Scenario: Explicit yolo subcommand
- **WHEN** `opencode-yolo yolo` is invoked
- **THEN** it SHALL launch `opencode` with `--auto` inside the sandbox

### Requirement: run mode launches opencode with normal permissions
`opencode-yolo run` SHALL ensure the `opencode-yolo` sandbox image exists and then launch `opencode` inside it without `--auto`, so opencode's normal interactive approval prompts apply.

#### Scenario: run launches opencode without auto-approve
- **WHEN** `opencode-yolo run` is invoked
- **THEN** it SHALL launch `opencode` inside the sandbox without the `--auto` flag

### Requirement: run and yolo build the image only when it doesn't already exist
Both `run` and `yolo` (including the no-args default) SHALL build the `opencode-yolo` sandbox image automatically when it does not already exist, and SHALL reuse the existing image without rebuilding when it does.

#### Scenario: First invocation with no existing image
- **WHEN** `opencode-yolo run` or `opencode-yolo yolo` is invoked and no `opencode-yolo` image exists yet
- **THEN** the image SHALL be built before the container is launched

#### Scenario: Subsequent invocation with an existing image
- **WHEN** `opencode-yolo run` or `opencode-yolo yolo` is invoked and an `opencode-yolo` image already exists
- **THEN** the existing image SHALL be reused and no build SHALL be performed

### Requirement: rebuild forces a fresh image build without launching a container
`opencode-yolo rebuild` SHALL force a fresh build of the `opencode-yolo` image, bypassing the kind of build-cache reuse that would otherwise skip picking up updated Dockerfile content or a newer `opencode-ai` version pin, and SHALL exit without launching a container. This build SHALL NOT affect the separately-tagged `claude-yolo` image.

#### Scenario: rebuild refreshes an already-existing image
- **WHEN** `opencode-yolo rebuild` is invoked and an `opencode-yolo` image already exists
- **THEN** a fresh build SHALL run rather than reusing the existing image unchanged
- **AND** the `claude-yolo` image tag SHALL be unaffected

#### Scenario: rebuild does not start the sandbox
- **WHEN** `opencode-yolo rebuild` completes
- **THEN** no container SHALL be started as part of that invocation

### Requirement: nuke resets the opencode-yolo image and persisted state
`opencode-yolo nuke` SHALL remove the `opencode-yolo` image and the persisted `opencode-yolo-home` volume, and SHALL ask for confirmation before doing so, since this deletes local state that cannot be recovered automatically. It SHALL NOT remove the `claude-yolo` image or the `claude-yolo-home` volume.

#### Scenario: nuke removes the image and the persisted volume
- **WHEN** `opencode-yolo nuke` is invoked and confirmed
- **THEN** the `opencode-yolo` image SHALL be removed
- **AND** the `opencode-yolo-home` volume SHALL be removed
- **AND** the `claude-yolo` image and `claude-yolo-home` volume SHALL be left untouched

#### Scenario: nuke requires confirmation
- **WHEN** `opencode-yolo nuke` is invoked
- **THEN** it SHALL prompt for confirmation before removing anything
- **AND** declining the prompt SHALL leave the image and volume untouched

### Requirement: extra arguments pass through to the opencode invocation
Arguments given after the subcommand (or after `opencode-yolo` itself when no subcommand is given) SHALL be forwarded to the `opencode` invocation inside the container, for both `run` and `yolo` modes.

#### Scenario: Arguments after an explicit subcommand
- **WHEN** `opencode-yolo run "models"` is invoked
- **THEN** `"models"` SHALL be passed through to the `opencode` command inside the container

#### Scenario: Arguments after the no-args default
- **WHEN** `opencode-yolo "--model mlx/some-model"` is invoked
- **THEN** that argument SHALL be passed through to the `opencode --auto` command inside the container, the same as `opencode-yolo yolo "--model mlx/some-model"` would

### Requirement: Workspace folder can be overridden at runtime
`opencode-yolo` SHALL accept a `--workspace <path>` option, given before the subcommand, that mounts `<path>` as `/workspace` inside the container instead of the script's default parent directory. When not given, the script's parent directory SHALL be mounted, and an invalid path SHALL fail clearly before any container starts.

#### Scenario: Explicit workspace path
- **WHEN** `opencode-yolo --workspace /some/other/project run` is invoked
- **THEN** `/some/other/project` SHALL be mounted as `/workspace` inside the container, rather than the script's default parent directory

#### Scenario: Nonexistent workspace path
- **WHEN** `opencode-yolo --workspace /no/such/folder run` is invoked and `/no/such/folder` does not exist
- **THEN** the script SHALL exit with an error identifying the invalid workspace path
- **AND** no container SHALL be started

### Requirement: opencode-yolo and claude-yolo build independent image tags from the same Dockerfile
`opencode-yolo` SHALL build and reference its own `opencode-yolo` image tag, distinct from `claude-yolo`'s `claude-yolo` tag, even though both are built from the same `Dockerfile`. Rebuilding or nuking one tag SHALL NOT alter the other.

#### Scenario: Building opencode-yolo does not touch the claude-yolo tag
- **WHEN** `opencode-yolo rebuild` is run and a `claude-yolo` image already exists
- **THEN** the `opencode-yolo` tag SHALL be (re)built
- **AND** the existing `claude-yolo` image SHALL be left unchanged
