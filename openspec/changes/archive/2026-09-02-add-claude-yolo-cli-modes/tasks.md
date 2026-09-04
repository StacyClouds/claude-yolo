## 1. Dockerfile entrypoint

- [x] 1.1 Change `ENTRYPOINT` from `["tini", "--", "claude", "--dangerously-skip-permissions"]` to `["tini", "--"]` and verify the image still builds
- [x] 1.2 Verify a container run with `docker run ... claude-yolo claude --dangerously-skip-permissions` (explicit args) behaves the same as the old hardcoded entrypoint did

## 2. Subcommand dispatch in claude-yolo

- [x] 2.1 Add `case "$1" in rebuild|nuke|run|yolo) ...; esac`-style dispatch that consumes a matched subcommand and shifts it off, defaulting to `yolo` behavior when no subcommand is given, and verify `claude-yolo somepromptword` (no reserved word) still forwards to `claude` unchanged
- [x] 2.2 Implement the image-exists check (e.g. `docker image inspect claude-yolo`) shared by `run` and `yolo`, and verify it correctly reports present vs. absent

## 3. yolo and run modes

- [x] 3.1 Implement `yolo` (and the no-args default): build only if the image is missing, then `docker run` into `claude --dangerously-skip-permissions "$@"`, and verify both a first run (no image) and a repeat run (existing image) behave per spec
- [x] 3.2 Implement `run`: same build-if-missing behavior, then `docker run` into `claude "$@"` (no `--dangerously-skip-permissions`), and verify Claude starts with normal permission prompts
- [x] 3.3 Verify trailing arguments reach the `claude` invocation for both `claude-yolo run "..."` and `claude-yolo "..."` (implicit yolo)

## 4. rebuild mode

- [x] 4.1 Implement `rebuild`: always run `docker build`, then exit without running a container, and verify it updates an already-existing image (e.g. after a `Dockerfile` edit) without starting a container

## 5. nuke mode

- [x] 5.1 Implement `nuke`: prompt for confirmation, and on confirmation remove the `claude-yolo` image and the `claude-yolo-home` volume; on decline, leave both untouched — verify both paths
- [x] 5.2 Verify `nuke` followed by `claude-yolo yolo` rebuilds the image from scratch and starts a fresh (logged-out) Claude session

## 6. Documentation

- [x] 6.1 Update the comment header in `claude-yolo` to describe the new subcommands, matching the style of its existing comments
