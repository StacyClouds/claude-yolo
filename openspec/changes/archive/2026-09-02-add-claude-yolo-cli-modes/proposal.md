## Why

Today `claude-yolo` does exactly one thing: `docker build` (every invocation, unconditionally) then `docker run` straight into `claude --dangerously-skip-permissions`. There's no way to just get a shell in the sandbox, run Claude with normal permission prompts instead of YOLO mode, force a fresh image rebuild on demand, or reset the sandbox entirely (image + persisted login) without doing it by hand with raw `docker` commands.

## What Changes

- `claude-yolo` gains explicit subcommands as its first argument:
  - `rebuild` — force a fresh `docker build` (bypassing the cache) and exit; does not run a container.
  - `nuke` — remove the built image and the `claude-yolo-home` volume (persisted Claude login), for a full reset. **BREAKING** in the sense that it deletes local state (the login volume) — prompts for confirmation before doing so.
  - `run` — ensure the image exists (building it only if missing, otherwise reusing what's already built), then launch `claude` with its normal permission prompts (no `--dangerously-skip-permissions`).
  - `yolo` — same image-ensure behavior as `run`, then launch `claude --dangerously-skip-permissions` (today's YOLO mode).
- Invoking `claude-yolo` with no subcommand keeps today's default: it behaves exactly like `yolo`.
- **BREAKING**: build behavior changes for `run`/`yolo` (and therefore the no-args default) — the image is no longer rebuilt on every invocation, only when it doesn't exist yet. Picking up `Dockerfile` changes or newer floating package versions (e.g. the .NET SDK patches from the `add-dotnet-and-opsx-baking` change) now requires explicitly running `claude-yolo rebuild`.
- Any arguments after the subcommand (or after `claude-yolo` itself, for the no-args-default case) are still forwarded to the `claude` invocation, e.g. `claude-yolo run "review this file"` or `claude-yolo "fix the bug"` (implicit yolo).
- The `Dockerfile`'s `ENTRYPOINT` changes from the hardcoded `["tini", "--", "claude", "--dangerously-skip-permissions"]` to just `["tini", "--"]`, so the script can choose which `claude` flags to pass per mode. This is an implementation detail with no behavioral effect on its own.

## Capabilities

### New Capabilities
- `sandbox/cli-modes`: the `claude-yolo` command line supports distinct `rebuild`, `nuke`, `run`, and `yolo` modes, plus a no-args default, each with clearly defined build/run/permission behavior.

### Modified Capabilities
(none)

## Impact

- `claude-yolo` (the run script): subcommand parsing and dispatch, conditional build-if-missing logic, confirmation prompt for `nuke`.
- `Dockerfile`: `ENTRYPOINT` simplified to `["tini", "--"]`; the `claude` command and its flags now come from the script, not baked into the image.
- Behavioral change for existing users: repeat `claude-yolo` invocations no longer re-run `docker build` once an image exists, so Dockerfile edits and floating package version bumps (.NET patches, plugin versions resolved at build time) won't take effect until `claude-yolo rebuild` is run explicitly.
- No change to the isolation model (still no `git`, still runs as `node`, still no host credentials copied in) and no change to how `/workspace` is mounted.
