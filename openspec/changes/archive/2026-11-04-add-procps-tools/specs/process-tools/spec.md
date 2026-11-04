## Purpose

Let agents and users inside the sandbox container find and stop processes with the standard commands instead of reading `/proc` by hand.

## ADDED Requirements

### Requirement: Process commands are installed in the image
The final stage of the image SHALL install the `procps` package, so that `ps`, `pgrep` and `pkill` are on the default `PATH`.

#### Scenario: Dockerfile installs procps
- **WHEN** the final-stage package install in the Dockerfile is read
- **THEN** it lists `procps`

#### Scenario: Commands available in a built container
- **WHEN** a container is started from a freshly built image
- **THEN** `pkill --version` exits with status 0
