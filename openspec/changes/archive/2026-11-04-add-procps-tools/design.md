## Context

The final stage installs its apt packages in one `RUN` (ca-certificates, curl, bash, tini, python3, jq, git, sudo). The existing tests are shell scripts that exercise `claude-yolo` and `entrypoint.sh` with stubs; none builds the image.

## Goals / Non-Goals

**Goals:**
- `ps`, `pgrep` and `pkill` in the image.

**Non-Goals:**
- Other tools such as `lsof`, `ss` or `netstat`; add them if a need appears.

## Decisions

- **Package `procps`** (Debian bookworm), added to the existing install line so no extra layer is created.
- **Test by reading the Dockerfile**: building the image in the test suite is too slow. The built-container scenario is checked manually in the tasks.

## Risks / Trade-offs

- A text check on the Dockerfile can pass while the build fails; the manual rebuild check covers that.
