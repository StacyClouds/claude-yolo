## 1. Script scaffolding

- [x] 1.1 Create `claude-yolo.ps1` at the repo root with `$PSScriptRoot`-based path resolution for the Dockerfile context and verify `docker build` is invoked against the correct build context when run from an unrelated working directory
- [x] 1.2 Implement subcommand dispatch (default/`yolo`, `run`, `rebuild`, `nuke`) matching `claude-yolo`'s `MODE` switch and verify each subcommand routes to the right branch with a dry-run print of the `docker` command it would execute

## 2. Core parity with the sh script

- [x] 2.1 Implement `--workspace <path>` parsing (must precede the subcommand), `Test-Path -PathType Container` validation, and error exit before any container starts; verify against `specs/sandbox/windows-launcher/spec.md` scenarios "Explicit workspace path" and "Nonexistent workspace path"
- [x] 2.2 Implement image existence check (`docker image inspect`) and conditional build for `run`/`yolo`, plus unconditional rebuild for `rebuild`; verify against the "Image built by the sh script is reused" scenario by pre-building the image via `claude-yolo` (under WSL/Git Bash) and confirming `claude-yolo.ps1 run` does not rebuild it
- [x] 2.3 Implement host config mount using `Join-Path $HOME '.claude'`, mounted read-only at `/home/node/.claude-host` only when present; verify both the "Host config folder present" and "No host config folder" scenarios
- [x] 2.4 Implement `ANTHROPIC_API_KEY` pass-through (only forwarded when set in the environment) and pass-through arguments to `claude` via array splatting (not string interpolation); verify with an argument containing spaces (e.g. `"fix the bug in Foo.cs"`) that it reaches `claude` as a single argument
- [x] 2.5 Implement `nuke`'s `Read-Host` confirmation prompt and, on accept, `docker rmi`/`docker volume rm`; verify both the "removes the image and volume when confirmed" and "leaves state untouched when declined" scenarios
- [x] 2.6 Implement `nuke --preserve-token`, reusing the identical inline `sh -c` helper-container script from `claude-yolo` (including the `busybox` fallback when the image doesn't exist yet); verify the "preserve-token keeps the login credential" scenario by confirming `~/.claude/.credentials.json` survives and everything else in the volume is removed

## 3. Documentation and CI

- [x] 3.1 Add a Windows section to `README.md`: prerequisites (Docker Desktop, PowerShell), how to make `claude-yolo` callable (add the script's folder to `PATH`, or a profile function), and the execution-policy/`Unblock-File` note from `design.md`
- [x] 3.2 Add a PSScriptAnalyzer job to `.github/workflows/lint.yml` alongside the existing `shellcheck`/`hadolint` jobs, scoped to `claude-yolo.ps1`, and verify it passes in CI

## 4. Manual verification

- [ ] 4.1 On a Windows machine with Docker Desktop, manually run through every scenario in `specs/sandbox/windows-launcher/spec.md` (default/`yolo`, `run`, `rebuild`, `nuke` with and without `--preserve-token`, `--workspace` valid/invalid, argument pass-through) and record results in the PR description, since CI has no Windows runner exercising `docker run`
