## Why

Apps run inside the container often need services that run on the host machine, such as the Cosmos DB and Azurite emulators. From inside the container `localhost` is the container itself, so connection strings copied from a normal dev setup fail. The host is reachable as `host.docker.internal`, but nothing tells an agent that. A skill gives agents the rule at the moment an app needs local access.

## What Changes

- Add a `host-services` skill, kept in the repo and baked into the image under `/opt/skills`.
- The skill explains: use `host.docker.internal` instead of `localhost` / `127.0.0.1`; how to probe whether a host port is open; connection string forms for Azurite and the Cosmos emulator; that the host's containers must publish their ports.
- The existing start-up backfill copies the skill into `~/.claude/skills`, unless the host's own `~/.claude` already provides one of that name.

## Capabilities

### New Capabilities
- `host-services-skill`: agents in the container get guidance for reaching services on the host.

### Modified Capabilities

## Impact

- New `skills/host-services/SKILL.md` in the repo.
- `Dockerfile`: one `COPY` into `/opt/skills`.
- `test/`: new check on the skill file and the Dockerfile copy.
- README: one line.
- Takes effect after `claude-yolo rebuild` and a fresh Claude Code session.
