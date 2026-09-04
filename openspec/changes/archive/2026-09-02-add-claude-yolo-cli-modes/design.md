## Context

`claude-yolo` is a small POSIX shell script (see proposal.md for its current behavior). It resolves its own real path (to work as a symlink on `PATH`), computes `PROJECT_DIR` as the parent of its own directory (the `stacyclouds` folder, so every sibling project can be mounted), then unconditionally runs `docker build` followed by `docker run` into a hardcoded `claude --dangerously-skip-permissions` entrypoint. There is no argument parsing today beyond forwarding `"$@"` straight into the container.

## Goals / Non-Goals

**Goals:**
- Add `rebuild`, `nuke`, `run`, and `yolo` as explicit first-argument subcommands, with a no-args default that behaves like `yolo`.
- Keep the existing `PROJECT_DIR`/mount/volume setup identical across all modes — only the build-or-not decision and the `claude` invocation flags change.
- Make the destructive `nuke` path require confirmation.

**Non-Goals:**
- Changing how `PROJECT_DIR` is computed or what gets mounted.
- Adding new Docker volumes, networks, or other resources beyond the existing `claude-yolo-home`.
- A `--help`/usage flag beyond what's needed to reject unrecognized subcommands clearly (nice-to-have, not required by this change).
- Changing anything inside the container's filesystem or the plugin/opsx/.NET baking from the prior change.

## Decisions

**1. Subcommand dispatch happens in the script via `case "$1" in ...`, consuming the matched subcommand and shifting it off before forwarding the rest of `"$@"` to `claude`.**
This keeps the script's existing "forward everything to claude" behavior for the common case (`claude-yolo "some prompt"`) while reserving four literal first words (`rebuild`, `nuke`, `run`, `yolo`) as mode selectors. A prompt that happens to start with one of those exact words is a known, accepted edge case (e.g. someone wanting to literally send "nuke" as a prompt would need `claude-yolo yolo nuke` instead) — not solved here, since reserving a handful of short English words is far simpler than inventing a flag syntax (`--rebuild` etc.) for what's meant to be quick, memorable commands.

**2. Build-if-missing is checked with `docker image inspect claude-yolo` (or equivalent), not by tracking build state in a file.**
Docker itself is the source of truth for whether the image exists; there's no need for the script to keep its own state. `run` and `yolo` both check this before deciding whether to build.

**3. `rebuild` always runs `docker build` (relying on Docker's normal layer caching, not `--no-cache`), and nothing else.**
Since `run`/`yolo` now skip building when an image already exists, `rebuild` becomes the only way to pick up `Dockerfile` edits or newer floating package versions (the .NET SDK patches and `dotnet-install.sh`/plugin-marketplace fetches from the prior change, all of which rely on being rebuilt to actually move forward — see that change's design.md, which assumed the image "rebuilds fresh on every claude-yolo invocation"; that assumption no longer holds and `rebuild` is the replacement). A plain `docker build` (not `--no-cache`) is enough for Dockerfile edits, since changed layers invalidate the cache from that point on automatically; a user chasing floating package updates with an unchanged Dockerfile would need `--no-cache` themselves, or a future change could add a `--no-cache` flag — not required to satisfy this change's proposal, so left out for now.

**4. `nuke` prompts with a plain `read -r` confirmation, defaulting to "no".**
Matches the shell script's existing style (`set -eu`, no external prompt libraries) and errs toward not deleting the user's Claude login unless they clearly confirm.

**5. `Dockerfile` `ENTRYPOINT` becomes `["tini", "--"]`; the script supplies `claude` and its mode flags as the trailing `docker run` arguments.**
Baking `--dangerously-skip-permissions` into `ENTRYPOINT` made it impossible to run `claude` any other way without a second image or an `--entrypoint` override on every invocation. Moving the `claude ...` invocation itself into the script's `docker run` command line is the minimal change that lets `run` and `yolo` differ only in which flags the script passes.

## Risks / Trade-offs

- **Behavioral change for existing users**: today, every invocation rebuilds (cheaply, via cache) — that was incidentally keeping floating versions (.NET patches, npm-pinned tool versions checked against their pinned tag, plugin marketplace state) fresh on every run. After this change, an existing image is reused indefinitely until `rebuild` is run explicitly. Mitigated by documenting this plainly in the proposal and in the script's own comments; no automatic staleness check is added (out of scope).
- **Reserved subcommand words shadow literal prompts**: a first prompt word matching `rebuild`/`nuke`/`run`/`yolo` exactly is consumed as a subcommand instead of forwarded. Mitigated by keeping the reserved set small and documented; users hitting this can prefix with `yolo` or `run` explicitly.
- **`nuke` removing the login volume is destructive and irreversible**: mitigated by the confirmation prompt (Decision 4); no snapshot/backup mechanism is added.
- **`docker image inspect`/`docker rmi`/`docker volume rm` failures (e.g. Docker daemon not running, image already absent)**: the script should surface the underlying Docker error rather than swallowing it — consistent with `set -eu` already causing the script to exit on unexpected command failures.

## Migration Plan

This is a local dev CLI tool, not a deployed service. Existing users of `claude-yolo` (just the author, currently) will notice the build-on-every-run behavior stop the next time they pull this change; the fix is simply to run `claude-yolo rebuild` whenever a fresh build is wanted. No data migration; the `claude-yolo-home` volume is untouched unless `nuke` is explicitly run and confirmed. Rollback is reverting the script and `Dockerfile` changes.
