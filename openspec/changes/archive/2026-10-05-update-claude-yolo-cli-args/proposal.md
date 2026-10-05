## Why

`claude-yolo`'s current argument parsing is ambiguous: a bare positional argument (e.g. `claude-yolo .`) is silently forwarded to `claude` inside the container as a prompt/argument, rather than being recognized as a likely attempt to override the workspace folder (today that requires the separate `--workspace <path>` flag). This leads to confusing, silent misroutes — a user typing `claude-yolo .` expecting it to mount the current directory instead gets `.` passed through to `claude` itself. There's also no `--help` output to clarify any of this at the command line.

## What Changes

- **BREAKING**: A bare positional argument (one that isn't `--help`/`-h`, `--workspace`, or a recognized subcommand keyword) is now interpreted as a workspace-path override, equivalent to `--workspace <path>`. It must be an existing directory or the script fails clearly before touching Docker. The existing `--workspace <path>` flag keeps working unchanged, as an explicit alternate spelling of the same thing.
- **BREAKING**: Arguments meant for the `claude` invocation inside the container (for `run`/`yolo` modes) must now come after a literal `--` separator. Any leftover positional argument that isn't `--` or a recognized workspace path/subcommand is now a clear error instead of being silently forwarded.
- Add `--help` / `-h`, which prints usage and exits without building an image, touching Docker, or requiring a workspace path.
- Update `README.md`'s `claude-yolo` usage section and the script's own top-of-file usage comment to document the new grammar.

## Capabilities

### New Capabilities
- `sandbox/cli-help`: `claude-yolo --help`/`-h` prints usage and exits cleanly with no side effects.

### Modified Capabilities
- `sandbox/workspace-selection`: a bare positional path argument is now an accepted alternate form of specifying the workspace override, validated the same way as `--workspace <path>`.
- `sandbox/cli-modes`: arguments forwarded to the `claude` invocation now require an explicit `--` separator; an unrecognized leftover positional argument is now a hard error rather than being forwarded.

## Impact

- `claude-yolo`: argument-parsing logic, and its top-of-file usage comment.
- `README.md`: the "Usage" and "Choosing the workspace folder" sections for `claude-yolo` (not `opencode-yolo`, which is a separate script and out of scope here).
- A new shell-based test harness is introduced for this script (the repo currently has none — only ShellCheck/Hadolint linting), per TDD: a fake `docker` stub on `PATH` lets tests assert what the script would have run without needing a real Docker daemon.
- Any existing muscle-memory or external docs/scripts invoking `claude-yolo <subcommand> <prompt text>` without `--` will break and need the `--` inserted.
