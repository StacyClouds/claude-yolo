## 1. Red: failing tests

- [x] 1.1 Add a test that `skills/host-services/SKILL.md` exists with `name: host-services` and a `description` line; run and confirm it fails
- [x] 1.2 Add a test that the skill text contains `host.docker.internal`, a port probe, ports 10000, 10001, 10002 and 8081
- [x] 1.3 Add a test that the Dockerfile copies the skill into `/opt/skills/host-services`
- [x] 1.4 Add an entrypoint test that a baked `host-services` skill is backfilled and a host-provided one is not overridden

## 2. Green: implementation

- [x] 2.1 Write `skills/host-services/SKILL.md`
- [x] 2.2 Add the `COPY` (with ownership for `node`) to the Dockerfile
- [x] 2.3 Run the test suites and confirm they pass

## 3. Verify and document

- [x] 3.1 Add a README line
- [x] 3.2 Run `claude-yolo rebuild`, start a container, confirm the skill is listed
- [x] 3.3 Run `openspec validate add-host-services-skill`
