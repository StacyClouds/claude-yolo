## Purpose

Tell agents in the sandbox container how to reach services running on the host machine, so apps started in the container can use the host's emulators and databases.

## ADDED Requirements

### Requirement: A host-services skill is baked into the image
The image SHALL contain a skill named `host-services` at `/opt/skills/host-services/SKILL.md`, with front matter containing `name: host-services` and a `description` that says when to use it (an app in the container needs a service running on the host).

#### Scenario: Skill file is present in the repo and copied by the Dockerfile
- **WHEN** the repo and Dockerfile are inspected
- **THEN** `skills/host-services/SKILL.md` exists with the required front matter, and the Dockerfile copies it to `/opt/skills/host-services`

### Requirement: The skill states the host address rule
The skill SHALL tell the agent to use `host.docker.internal` in place of `localhost` and `127.0.0.1` for services on the host, and SHALL give a way to check that a host port is open from inside the container.

#### Scenario: Rule and probe are documented
- **WHEN** the skill text is read
- **THEN** it contains `host.docker.internal`, and a port probe command

### Requirement: The skill covers Azurite and the Cosmos emulator
The skill SHALL give the endpoint form for Azurite blob, queue and table services (ports 10000, 10001, 10002) and for the Cosmos emulator (port 8081), and SHALL note that the host's containers must publish those ports.

#### Scenario: Emulator endpoints documented
- **WHEN** the skill text is read
- **THEN** it names ports 10000, 10001, 10002 and 8081 with `host.docker.internal` endpoints

### Requirement: The skill is available at start-up
The start-up backfill SHALL make the skill available in `~/.claude/skills`, without overriding a skill of the same name provided by the host.

#### Scenario: Backfilled when absent
- **WHEN** the entrypoint runs with the skill in the baked skills directory and none in the host's
- **THEN** `~/.claude/skills/host-services/SKILL.md` exists
