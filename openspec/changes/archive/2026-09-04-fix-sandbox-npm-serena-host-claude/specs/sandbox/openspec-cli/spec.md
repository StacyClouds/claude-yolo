## Purpose

Keeps the `openspec` CLI itself globally installed and runnable inside the sandbox, independent of the opsx-tooling bake, so a user can scaffold OpenSpec into any mounted project from scratch.

## ADDED Requirements

### Requirement: openspec CLI is installed and runnable
The sandbox image SHALL have the `openspec` CLI installed globally and runnable by the `node` user, independent of whether opsx commands/skills are baked or shadowed by a host `~/.claude` mount (see `sandbox/opsx-tooling`).

#### Scenario: openspec CLI present
- **WHEN** `openspec --version` is run inside the container as the `node` user
- **THEN** it SHALL print a version number rather than a command-not-found error

### Requirement: openspec init scaffolds a fresh mounted project
Running `openspec init` inside a mounted project directory that has no existing OpenSpec scaffolding SHALL create one for that project, regardless of whether that project previously had any OpenSpec files.

#### Scenario: Init in a project with no OpenSpec scaffolding
- **WHEN** a user runs `openspec init` inside a mounted project folder under `/workspace` that has no `openspec/` directory
- **THEN** `openspec init` SHALL create OpenSpec scaffolding in that project folder
