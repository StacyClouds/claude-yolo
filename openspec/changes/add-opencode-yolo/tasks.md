## 1. Dockerfile: install opencode

- [x] 1.1 Add `ARG OPENCODE_VERSION=1.18.34` near the existing `CLAUDE_VERSION`/`OPENSPEC_VERSION` args, and add `opencode-ai@${OPENCODE_VERSION}` to the existing `npm install -g` step; verify `docker build -t opencode-yolo .` succeeds and `docker run --rm opencode-yolo opencode --version` prints `1.18.34`
- [x] 1.2 `COPY --chown=root:root opencode-entrypoint.sh /usr/local/bin/opencode-entrypoint.sh` and `chmod +x` it, alongside the existing `entrypoint.sh` copy step; verify the file is present and executable in the built image (`docker run --rm --entrypoint sh opencode-yolo -c 'ls -l /usr/local/bin/opencode-entrypoint.sh'`)
- [x] 1.3 Verify the existing `claude-yolo` build/behavior is unaffected: `docker build -t claude-yolo .` still succeeds and `docker run --rm claude-yolo claude --version` still works

## 2. opencode-entrypoint.sh: local model discovery and config

- [x] 2.1 Write `opencode-entrypoint.sh` (`set -eu`, modeled on `entrypoint.sh`'s structure) that reads `MLX_BASE_URL`, defaulting to `http://host.docker.internal:8000`
- [x] 2.2 Implement the discovery step: `curl` (with a short timeout and failure tolerance) `GET $MLX_BASE_URL/v1/models`, extract `.data[0].id` with `jq`; verify against a local stub server (e.g. `python3 -m http.server` won't do — use a tiny one-off script or `nc` returning a canned OpenAI-style `/v1/models` JSON body) that the correct id is extracted
- [x] 2.3 On successful discovery, merge (not overwrite) `~/.config/opencode/opencode.json` via `jq`, setting `provider.mlx` (`npm: "@ai-sdk/openai-compatible"`, `options.baseURL: $MLX_BASE_URL/v1`, `options.apiKey: "not-needed"`, `models.<id>: {}`), `model: "mlx/<id>"`, and `autoupdate: false`; verify a pre-existing `opencode.json` with an unrelated key keeps that key after the merge
- [x] 2.4 On discovery failure (unreachable server, empty `data` list, or malformed response), print a clear warning to stderr naming the configured `MLX_BASE_URL` and continue without writing the `provider.mlx`/`model` keys; verify the container still starts (`exec tini -- "$@"` still runs) when nothing is listening on the configured address
- [x] 2.5 End the script with `exec tini -- "$@"`, matching `entrypoint.sh`'s pattern

## 3. opencode-yolo script

- [x] 3.1 Create `opencode-yolo`, copying `claude-yolo`'s symlink-resolution, `--workspace` handling, and subcommand dispatch structure, with `IMAGE=opencode-yolo` and `VOLUME=opencode-yolo-home`
- [x] 3.2 Implement `run_container()` to pass `--entrypoint /usr/local/bin/opencode-entrypoint.sh`, `--add-host=host.docker.internal:host-gateway`, `-v "$PROJECT_DIR":/workspace`, `-v "$VOLUME":/home/node`, and forward `MLX_BASE_URL` into the container when set on the host; verify with `docker run --rm --entrypoint sh opencode-yolo -c 'getent hosts host.docker.internal'` that the mapping resolves
- [x] 3.3 Implement `yolo` (default) and `run` modes: build-if-missing against the `opencode-yolo` tag, then launch `opencode --auto "$@"` or `opencode "$@"` respectively; verify both with a stub/no model server present (container still starts, see 2.4) and with one present (opencode shows the discovered model as default, e.g. via `opencode-yolo run "models"` showing `mlx/<id>`)
- [x] 3.4 Implement `rebuild`: `docker build -t opencode-yolo .`, no container launched; verify it does not touch an existing `claude-yolo` image (`docker image inspect claude-yolo` reports the same image ID before and after)
- [x] 3.5 Implement `nuke`: confirmation prompt, then remove the `opencode-yolo` image and `opencode-yolo-home` volume only; verify declining leaves both intact, and confirming removes only those two resources (`claude-yolo`/`claude-yolo-home` untouched)
- [x] 3.6 Verify `--workspace` behavior matches `claude-yolo`'s: an explicit valid path is mounted as `/workspace`, an invalid path fails before any container starts, and two concurrent invocations with different `--workspace` paths run independently while sharing `opencode-yolo-home`

## 4. Documentation

- [x] 4.1 Add an `opencode-yolo` section to `README.md`: prerequisites (an OpenAI-compatible local server, e.g. MLX's, already running), installation (symlink alongside `claude-yolo`), subcommand table, and the `MLX_BASE_URL` override — verify by following the written steps end-to-end against a real local MLX server
- [x] 4.2 Run `openspec validate add-opencode-yolo --strict` and fix any reported issues

## Verification note

The first implementation pass ran in a sandbox with no `docker` binary
available, so those tasks were implemented and then verified by the closest
available substitute instead of the literal `docker build`/`docker run`
commands in their descriptions:

- **ShellCheck** (downloaded locally, matching the repo's lint CI) passes
  clean on `opencode-yolo` and `opencode-entrypoint.sh`.
- **2.1-2.5**: `opencode-entrypoint.sh` was run directly (outside Docker)
  against a throwaway Python stub serving `/v1/models`, confirming both the
  successful-merge path (including that a pre-existing unrelated key in
  `opencode.json` survives) and the unreachable-server warn-and-continue
  path.
- **3.1-3.6**: `opencode-yolo` was run against a fake `docker` shim on
  `PATH` that logs its arguments, confirming: build-if-missing dispatch,
  the exact `run` flags (`--entrypoint`, `--add-host`, volumes, `--auto`
  vs. not), `rebuild`/`nuke` only ever naming the `opencode-yolo` tag/volume
  (never `claude-yolo`'s), and `--workspace` validation (valid path mounted,
  invalid path rejected before any container is started) — all without a
  real Docker daemon.
The Docker-daemon-dependent checks — 1.3, and the daemon-dependent halves of
1.1/1.2/3.2/3.3/4.1 — were then completed on a real Docker install:
`opencode-yolo rebuild` built the image, `opencode --version` reported the
pinned `OPENCODE_VERSION`, `host.docker.internal` resolved inside a real
container, and a real `opencode` session against a real local MLX server
picked up the discovered model as its default end to end (the working
session this change was reviewed in). The `claude-yolo` image built and ran
unaffected.
