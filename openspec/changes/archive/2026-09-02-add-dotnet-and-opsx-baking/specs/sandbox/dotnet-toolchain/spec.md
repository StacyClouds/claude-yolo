## Purpose

Provides .NET SDKs inside the sandbox image so mounted .NET projects can be built, tested, and run without leaving the container.

## ADDED Requirements

### Requirement: Multiple .NET SDK versions available
The sandbox image SHALL provide the .NET SDK for major versions 8, 9, and 10, each independently usable via `dotnet build`/`run`/`test` against its matching target framework moniker.

#### Scenario: .NET 8 SDK present
- **WHEN** `dotnet --list-sdks` is run inside the container
- **THEN** an 8.x SDK entry SHALL be listed

#### Scenario: .NET 9 SDK present
- **WHEN** `dotnet --list-sdks` is run inside the container
- **THEN** a 9.x SDK entry SHALL be listed

#### Scenario: .NET 10 SDK present
- **WHEN** `dotnet --list-sdks` is run inside the container
- **THEN** a 10.x SDK entry SHALL be listed

### Requirement: Latest .NET 11 preview available
The sandbox image SHALL provide the latest available preview build of the .NET 11 SDK, so mounted projects can be tried against the upcoming release ahead of its GA.

#### Scenario: .NET 11 preview SDK present
- **WHEN** `dotnet --list-sdks` is run inside the container
- **THEN** an 11.x SDK entry SHALL be listed

#### Scenario: Preview build floats to the newest available, not a fixed version
- **WHEN** the sandbox image is rebuilt after Microsoft publishes a newer .NET 11 preview
- **THEN** the rebuilt image SHALL pick up that newer preview build, rather than staying pinned to whichever preview was newest at an earlier build

### Requirement: .NET tooling runs as the unprivileged sandbox user
The .NET SDKs SHALL be usable by the non-root `node` user the container runs as, without requiring elevated privileges or additional permission grants.

#### Scenario: Build as the node user
- **WHEN** a mounted .NET project is built with `dotnet build` while running as the `node` user
- **THEN** the build SHALL succeed without permission errors
