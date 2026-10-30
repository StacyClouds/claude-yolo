## 1. Test harness

- [x] 1.1 Add an entrypoint test file under `test/` that runs `entrypoint.sh` against temporary host, local and baked directories with a stub `tini` on `PATH`; verify it fails because the entrypoint paths cannot yet be overridden (red)
- [x] 1.2 Make the entrypoint's fixed paths overridable by environment variables with the current values as defaults; verify the harness runs and the existing `test/claude-yolo.test.sh` still passes

## 2. Default status line (red, then green)

- [x] 2.1 Add failing tests for each scenario in `specs/sandbox/host-claude-config/spec.md` (neither script nor setting, no host folder, host script, host `statusLine`, host script without setting, repeated starts) plus a stale default already on the volume; verify all fail for the right reason
- [x] 2.2 Install the baked `statusline-command.sh` from `/opt/statusline` in `entrypoint.sh` whenever the host provides none, replacing any older copy on the volume; verify the script-related tests pass
- [x] 2.3 Add the `jq` step that sets `statusLine` only when absent; verify all tests from 2.1 pass

## 3. Image build

- [x] 3.1 Add `!statusline-command.sh` to `.dockerignore`; verify `git diff .dockerignore` shows only the added line
- [x] 3.2 Copy `statusline-command.sh` to `/opt/statusline/` in the `Dockerfile`; verify the repository's hadolint workflow configuration passes on the changed file
- [ ] 3.3 Run `claude-yolo rebuild` on a machine with Docker, then start a container with an empty `~/.claude` and verify the status line renders and `statusLine` is present in the container's `settings.json`

## 4. Documentation

- [x] 4.1 Update `README.md` to state that the image includes a default status line and that a host script or setting overrides it; verify the text matches the spec
