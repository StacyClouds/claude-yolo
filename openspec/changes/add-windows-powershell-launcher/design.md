## Context

`claude-yolo` (the `sh` script) resolves its own symlink to find `$SCRIPT_DIR`, builds/runs the `claude-yolo` image via `docker build`/`docker run`, mounts `$HOME/.claude` read-only when present, and drives a `nuke` flow that spins up a short-lived helper container to selectively preserve `~/.claude/.credentials.json` inside the `claude-yolo-home` volume. See `proposal.md` for why a native Windows entry point is needed. The container image, `entrypoint.sh`, and the `sandbox/cli-modes`/`sandbox/workspace-selection` specs are launcher-agnostic and unchanged by this design — everything here is about the outer orchestration script only.

## Goals / Non-Goals

**Goals:**
- `claude-yolo.ps1` reaches behavioral parity with `claude-yolo` for every subcommand and flag, runnable from `cmd.exe` (via `powershell.exe -File`) or a native PowerShell/PowerShell 7 session.
- Argument forwarding to `claude` preserves exact argument boundaries (no re-splitting or glob expansion of an argument that happens to contain spaces or wildcard characters).
- Reuses the same image name, volume name, and inner helper-container `sh -c` script as the `nuke --preserve-token` flow, so behavior doesn't quietly drift between the two launchers over time.

**Non-Goals:**
- Reproducing the `sh` script's symlink-resolution trick. Windows symlink resolution from PowerShell has version-dependent quirks (see Decisions), and Windows tooling doesn't conventionally rely on symlinking onto `PATH` the way Unix dotfiles do.
- A signed script or an installer/MSI. This is a plain `.ps1` file; execution-policy guidance goes in the README, not in the script.
- Changing anything inside the container (`Dockerfile`, `entrypoint.sh`, `git-wrapper.sh`) — this change is additive at the launcher layer only.

## Decisions

**No symlink-following; PATH installation is a directory add, not a symlink.**
The `sh` script manually walks symlinks because Unix users conventionally symlink a single script onto `PATH` (`ln -s ... ~/.local/bin/claude-yolo`). PowerShell's `$PSScriptRoot` does not reliably resolve through a reparse point the same way across Windows PowerShell 5.1 and PowerShell 7, and Windows symlinks need elevated privilege or Developer Mode to create in the first place. Instead, `claude-yolo.ps1` uses `$PSScriptRoot` directly (the directory the file actually lives in) and the README tells Windows users to add that directory to `PATH`, or define a PowerShell profile function that calls the script by its full path — no symlink involved. Alternative considered: reimplement reparse-point resolution with `[System.IO.FileSystemInfo]::ResolveLinkTarget` (PowerShell 7.2+ only) — rejected because it would silently misbehave on Windows PowerShell 5.1, which many Windows machines still run by default.

**Argument forwarding uses array splatting, not string concatenation.**
`$args` (or an explicitly parsed remainder array) is passed to `docker run ... claude @claudeArgs`, never interpolated into a single string. This is the PowerShell equivalent of the `sh` script's `"$@"` — it keeps `claude-yolo.ps1 run "fix the bug in Foo.cs"` from being re-split on spaces before it reaches `claude`.

**Reuse the exact inner helper-container script for `nuke --preserve-token`.**
The credential-preserving logic (copy `.credentials.json` out, wipe the volume, copy it back in) already runs *inside* a Linux container via `docker run ... sh -c '...'`. That inner script is POSIX `sh` regardless of which host script invoked it, so `claude-yolo.ps1` passes the identical inline script string used by `claude-yolo`, changing only the outer PowerShell orchestration (confirmation prompt, `docker volume inspect`/`docker rmi` calls, `$IMAGE`/busybox fallback selection). This keeps the two launchers from drifting into subtly different preserve-token semantics.

**Host config path: `$HOME\.claude`, not manual `$env:USERPROFILE` construction.**
PowerShell (both Windows PowerShell 5.1 and PowerShell 7) defines the automatic `$HOME` variable as the user's profile directory, so `Join-Path $HOME '.claude'` is the direct Windows analogue of the `sh` script's `$HOME/.claude` — no separate `$env:USERPROFILE` fallback needed.

**Windows paths are passed to `docker run -v` as-is.**
Docker Desktop's CLI translates a Windows path (e.g., `C:\Users\stace\project`) given to `-v` into the right mount inside its Linux VM automatically. No `wslpath`/`cygpath`-style conversion is needed in the script; `--workspace` validation just needs `Test-Path -PathType Container` on the given path before resolving it to a full path with `Resolve-Path`.

## Risks / Trade-offs

- **Windows PowerShell 5.1 vs PowerShell 7 differences** (e.g., default string comparison, `Start-Process` vs direct native calls) → mitigate by calling `docker` as a plain native command (`docker run @dockerArgs`) rather than `Start-Process`, which behaves consistently across both, and by avoiding version-specific cmdlets identified in Decisions above.
- **Execution policy may block running an unsigned local script** → not solved in-script; README documents `powershell -ExecutionPolicy Bypass -File claude-yolo.ps1 ...` or unblocking the file once via `Unblock-File`, mirroring how the `sh` script already assumes an executable bit is set.
- **Drift between the two launcher scripts over time** (a future change to `claude-yolo` not mirrored in `claude-yolo.ps1`) → mitigated structurally by reusing the same image/volume names and the same inner helper-container script (see Decisions), but full behavioral parity for *future* changes isn't automatically enforced; `tasks.md` should note updating both scripts together going forward.
- **No CI coverage for the new script's actual runtime behavior** (no Windows runner exercises `docker run` in this repo's CI) → mitigate with static analysis only (PSScriptAnalyzer alongside the existing ShellCheck job) and manual verification steps called out in `tasks.md`; functional parity relies on the spec's scenarios being checked by hand before merge.
