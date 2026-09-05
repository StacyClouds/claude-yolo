## Why

`claude-yolo` is a POSIX `sh` script: it resolves its own symlink, shells out to `docker build`/`docker run`, and prompts for confirmation on `nuke`. That runs fine under WSL or Git Bash, but there is no way to launch the sandbox from a plain Windows shell (`cmd.exe` or PowerShell) without going through one of those POSIX layers first. Windows users who have Docker Desktop but not WSL/Git Bash currently can't use the sandbox at all.

## What Changes

- Add `claude-yolo.ps1`, a PowerShell port of `claude-yolo` with the same subcommands and behavior: default/`yolo`, `run`, `rebuild`, `nuke` (with `--preserve-token`), and `--workspace <path>` (must precede the subcommand), plus pass-through arguments to `claude`.
- Same image/volume names (`claude-yolo`, `claude-yolo-home`) and the same `docker build`/`docker run` invocations, so a project already using the `sh` script on one machine and the PowerShell script on another share the same image and persisted login volume.
- Host `~/.claude` config mount and `ANTHROPIC_API_KEY` pass-through mirror the `sh` script, using `$env:USERPROFILE\.claude` as the Windows equivalent of `$HOME/.claude`.
- `nuke`'s confirmation prompt and (with `--preserve-token`) the credential-preserving helper-container flow are reproduced with the same semantics.
- README gets a Windows section: prerequisites (Docker Desktop, PowerShell), how to make `claude-yolo` callable by name, and any execution-policy note needed to run an unsigned local script.

## Capabilities

### New Capabilities
- `sandbox/windows-launcher`: a PowerShell entry point (`claude-yolo.ps1`) that provides the same CLI modes, workspace selection, and image/volume lifecycle as the `sh` `claude-yolo` script, for users invoking it from `cmd.exe`/PowerShell without WSL or Git Bash.

### Modified Capabilities
None. Existing `sandbox/*` specs describe the sandbox's CLI behavior in launcher-agnostic terms; the new script must conform to those same requirements rather than change them. `sandbox/cli-modes` and `sandbox/workspace-selection` are referenced, not modified.

## Impact

- New file: `claude-yolo.ps1` at the repo root (no changes to `claude-yolo`, `Dockerfile`, or `entrypoint.sh` — the container image and its entrypoint are launcher-agnostic).
- `README.md`: new Windows installation/usage section.
- `.hadolint.yaml`/lint workflow: no change expected, but `tasks.md` should confirm whether the existing Lint CI workflow needs a PowerShell linter (e.g. PSScriptAnalyzer) added for the new file.
