## Purpose

Makes the opsx workflow commands and openspec skills available to Claude inside the sandbox for every mounted project, independent of that project's own OpenSpec scaffolding.

## ADDED Requirements

### Requirement: opsx commands available regardless of mounted project
The sandbox image SHALL make the `/opsx:propose`, `/opsx:explore`, `/opsx:apply`, `/opsx:archive`, and `/opsx:sync` commands available to Claude Code for any project mounted at `/workspace`, whether or not that project has its own OpenSpec Claude scaffolding.

#### Scenario: Command available in a project without local opsx scaffolding
- **WHEN** Claude Code runs inside the container against a mounted project that has no `.claude/commands/opsx` directory of its own
- **THEN** the `/opsx:explore` command, and the other opsx commands, SHALL still be available

### Requirement: openspec skills available regardless of mounted project
The sandbox image SHALL make the openspec skills (explore, propose, apply, archive, sync-specs) available to Claude Code for any mounted project, independent of that project's own `.claude/skills` scaffolding.

#### Scenario: Skill available in a project without local skill scaffolding
- **WHEN** Claude Code runs inside the container against a mounted project that has no `.claude/skills/openspec-*` directories of its own
- **THEN** the openspec skills SHALL still be discoverable by Claude Code

### Requirement: baking is additive, not destructive
Baking the opsx commands and openspec skills into the user home directory SHALL NOT remove or overwrite unrelated existing content already present under `/home/node/.claude`.

#### Scenario: Plugin configuration preserved
- **WHEN** the opsx baking step runs after plugin configuration has already been copied into `/home/node/.claude`
- **THEN** the existing plugin configuration files SHALL remain unchanged
- **AND** the opsx commands and openspec skills SHALL be added alongside them
