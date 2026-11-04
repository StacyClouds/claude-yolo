## Why

Agents in the container start background processes (test servers, Aspire apps) and need to stop them. The image has no `pkill`, `pgrep` or `ps`, so an agent has to walk `/proc` by hand to find and kill a process. The `procps` package provides all three.

## What Changes

- Add `procps` to the final-stage `apt-get install` list in the Dockerfile.
- Add a test that checks the Dockerfile installs it.

## Capabilities

### New Capabilities
- `process-tools`: standard process inspection and signalling commands (`ps`, `pgrep`, `pkill`) are available in the container.

### Modified Capabilities

## Impact

- `Dockerfile`: one package added to the final stage; a few hundred kilobytes.
- `test/`: one new check.
- Takes effect after the next `claude-yolo rebuild`; a running container does not gain it.
