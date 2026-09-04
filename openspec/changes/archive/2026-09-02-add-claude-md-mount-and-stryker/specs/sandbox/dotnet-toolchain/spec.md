## ADDED Requirements

### Requirement: Mutation testing tool available
The sandbox image SHALL provide `dotnet-stryker` as a global `dotnet` tool, invokable as `dotnet stryker` against any mounted .NET project.

#### Scenario: Stryker command available
- **WHEN** `dotnet stryker --help` is run inside the container
- **THEN** it SHALL print Stryker's usage text rather than failing with an unknown-command error
- **AND** `dotnet tool list -g` SHALL list `dotnet-stryker` among the installed global tools

### Requirement: Stryker runs as the unprivileged sandbox user
`dotnet-stryker` SHALL be usable by the non-root `node` user the container runs as, without requiring elevated privileges or additional permission grants.

#### Scenario: Run Stryker as the node user
- **WHEN** `dotnet stryker` is run against a mounted .NET project while running as the `node` user
- **THEN** it SHALL start a mutation test run without permission errors
