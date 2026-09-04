## 1. CLAUDE.md run-time mount

- [x] 1.1 In `claude-yolo`, build a `CLAUDE_MD_MOUNT` variable set to `--volume=$HOME/.claude/CLAUDE.md:/home/node/.claude/CLAUDE.md:ro` only when `[ -f "$HOME/.claude/CLAUDE.md" ]`, and verify the script still parses (`sh -n`)
- [x] 1.2 Add `${CLAUDE_MD_MOUNT:+"$CLAUDE_MD_MOUNT"}` to `run_container`'s `docker run` arguments (used by both `run` and `yolo`), and verify the resulting `docker run` invocation includes the mount when the host file exists
- [x] 1.3 Verify inside a running container that `/home/node/.claude/CLAUDE.md` contains the host file's current content
- [x] 1.4 Verify the mount is read-only: an attempted write to `/home/node/.claude/CLAUDE.md` from inside the container fails
- [x] 1.5 Verify editing the host file and re-running `claude-yolo` (no rebuild) picks up the new content
- [x] 1.6 Verify `claude-yolo run`/`yolo` still start normally when the host has no `~/.claude/CLAUDE.md` (temporarily rename it, confirm no error, restore it)

## 2. dotnet-stryker

- [x] 2.1 Move `ENV HOME=/home/node` earlier in the `Dockerfile` final stage (before the .NET/tool install steps) and remove the now-redundant later occurrence; verify the image still builds
- [x] 2.2 Add `RUN dotnet tool install -g dotnet-stryker` before the existing `chown -R node:node /home/node` step, and add `/home/node/.dotnet/tools` to `PATH`; verify the build completes
- [x] 2.3 Verify Stryker resolves and runs inside the container as the `node` user (`dotnet stryker --help` prints usage text; `dotnet tool list -g` lists `dotnet-stryker`) — note: Stryker's CLI has no `--version` flag, so the task/spec wording was corrected from the originally planned `dotnet stryker --version` check
- [x] 2.4 Verify the earlier `ENV HOME` move didn't regress anything: re-run the `add-dotnet-and-opsx-baking` verification checks (`dotnet --list-sdks` shows 8/9/10/11-preview, opsx commands/skills present under `/home/node/.claude`, plugin config intact, `git` still disabled)
