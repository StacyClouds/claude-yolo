## Why

`claude-yolo` only runs Claude Code. There's no equivalent for driving a local model through [`opencode`](https://opencode.ai) inside the same isolated sandbox — someone wanting to point an agent at a model served locally (e.g. an MLX server on `localhost:8000`) has to improvise `docker run` by hand, with none of the git-push guard, workspace mount conventions, or shared tooling (.NET, serena, OpenSpec) this repo already bakes in.

## What Changes

- A new `opencode-yolo` script, mirroring `claude-yolo`'s subcommands (`yolo`, `run`, `rebuild`, `nuke`, no-args default) and `--workspace` handling, but launching `opencode` instead of `claude`:
  - `yolo [args...]` — `opencode --auto [args...]` (auto-approve, opencode's equivalent of `--dangerously-skip-permissions`).
  - `run [args...]` — `opencode [args...]` with opencode's normal interactive approval.
  - `rebuild` / `nuke` — same semantics as `claude-yolo`, scoped to a separate `opencode-yolo` image tag and `opencode-yolo-home` volume (see Impact).
- The existing `Dockerfile` gains `opencode-ai` (pinned via a new `OPENCODE_VERSION` build arg) installed globally alongside `@anthropic-ai/claude-code`, so one image serves both tools.
- A new `opencode-entrypoint.sh`, used only by `opencode-yolo` (via `docker run --entrypoint`), that on every container start probes an OpenAI-compatible model server (default `http://host.docker.internal:8000`, overridable with `MLX_BASE_URL`) for its currently-loaded model via `GET /v1/models`, and writes an opencode provider configuration pointing at that server with the discovered model set as the default — so the user never has to name a model themselves, and the sandbox tracks whatever model the local server currently has loaded.
- `opencode-yolo`'s container is started with `--add-host=host.docker.internal:host-gateway` so it can reach a server bound to `localhost` on the host (needed on Linux; Docker Desktop already provides this mapping, where the flag is a harmless no-op).
- README updated with an `opencode-yolo` section covering setup (an MLX server, or any other OpenAI-compatible local server, must already be running) and the `MLX_BASE_URL` override.

## Capabilities

### New Capabilities
- `sandbox/opencode-yolo-cli`: the `opencode-yolo` command line and its `yolo`/`run`/`rebuild`/`nuke`/no-args modes, built on the same shared image and isolation model (`/workspace` mount, blocked `git push`, no host credentials) as `claude-yolo`.
- `sandbox/opencode-local-model-provider`: `opencode-entrypoint.sh` auto-discovers the model currently loaded on a local OpenAI-compatible server and configures `opencode` to use it as the default, without the user naming a model.

### Modified Capabilities
(none — `claude-yolo`'s own behavior, image tag, and volume are unaffected)

## Impact

- `Dockerfile`: new `OPENCODE_VERSION` build arg, `opencode-ai` added to the global `npm install -g` step; no change to existing layers' behavior.
- New files: `opencode-yolo` (run script), `opencode-entrypoint.sh` (container entrypoint).
- `README.md`: new section documenting `opencode-yolo`.
- Build/runtime footprint: the shared image tag is built twice under two names (`claude-yolo` and `opencode-yolo`) so each script's `rebuild`/`nuke` only ever affects its own tag and home volume — Docker's layer cache makes the second build near-instant once the first has run.
- No change to `claude-yolo`'s image tag, volume, entrypoint, or git-push restriction.
- Network reachability: `opencode-yolo` containers can reach the host's loopback-bound ports via `host.docker.internal`, which `claude-yolo` containers do not need and do not get.
