## Context

`frontend-design` is fetched at build time into `/opt/skills`, and `entrypoint.sh` backfills `/opt/skills` into `~/.claude/skills` on every start, skipping names the host already provides. `/home/node` is a named volume, so skills must be baked outside it. `host.docker.internal` already resolves inside the container (Docker Desktop). Observed with the emulators running: Azurite answers over plain HTTP on 10000-10002; the Cosmos emulator on 8081 is the plain-HTTP variant and advertises `http://host.docker.internal:8081/` as its account endpoint when reached by that name.

## Goals / Non-Goals

**Goals:**
- Agents know the address rule and the emulator endpoints without being told.

**Non-Goals:**
- Making `localhost` work inside the container (a port forwarder); a separate change if wanted.
- Linux-host support (`--add-host`); the skill mentions the limit only.
- Secrets handling (see share-host-user-secrets).

## Decisions

- **Keep the skill in the repo and `COPY` it**, rather than fetching it, since it is this project's own content. The existing backfill needs no change.
- **One general skill** (`host-services`) with Azurite and Cosmos sections, so other host services (a database, a queue) follow the same rule.
- **Test as text checks** on the skill file and Dockerfile, plus the existing entrypoint backfill test pattern for the copy; the image is not built in tests.

## Risks / Trade-offs

- Endpoint details can drift with emulator versions; the skill states what was observed and tells the agent to probe first.
- Skill descriptions only trigger when the model judges them relevant; the description names the concrete cases (Cosmos, Azurite, "connection refused on localhost").
