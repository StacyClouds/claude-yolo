## Why

Two unrelated gaps, bundled into one change since they land in the same run/build flow:

1. Claude inside the sandbox has no access to the user's global `CLAUDE.md` (`~/.claude/CLAUDE.md` on the host) — the base instructions ("who I am", personality, tooling conventions) that shape how Claude should work with this user everywhere else. Confirmed nothing copies it in today: both `Dockerfile` `COPY` lines pull `--from=builder`, never from the host, and `.dockerignore` (`**`) excludes the build context entirely regardless.
2. The .NET toolchain added in `add-dotnet-and-opsx-baking` has SDKs but no mutation-testing tool. Stryker.NET (`dotnet-stryker`) is the standard mutation testing tool for .NET and is missing.

## What Changes

- `claude-yolo` bind-mounts the host's `~/.claude/CLAUDE.md` **read-only** into the container at `/home/node/.claude/CLAUDE.md` (Claude Code's global-instructions path, given `HOME=/home/node` in the sandbox), for both `run` and `yolo` modes. Mounted at container **run** time, not baked into the image at build time — this always reflects whatever the file currently is on the host, with no rebuild ever required. If the host file doesn't exist, the mount is skipped rather than erroring.
- Install `dotnet-stryker` as a global `dotnet` tool in the final image (`dotnet tool install -g dotnet-stryker`, unpinned — always installs whatever's newest on NuGet at build time, matching how the .NET 11 preview already floats), usable as `dotnet stryker` against any mounted .NET project, by the unprivileged `node` user.
- No changes to `nuke`/`rebuild` behavior, to how `/workspace` is mounted, or to the isolation model.

## Capabilities

### New Capabilities
- `sandbox/claude-global-instructions`: the sandbox gives Claude access to the host's global `CLAUDE.md`, kept live via a run-time mount rather than a build-time copy.

### Modified Capabilities
- `sandbox/dotnet-toolchain`: adds `dotnet-stryker` (mutation testing) as an additional tool available in the toolchain, alongside the existing SDKs.

## Impact

- `claude-yolo` (the run script): a new conditional volume mount added to `run_container`, applied to both `run` and `yolo` modes.
- `Dockerfile` (final stage only): new `dotnet tool install -g dotnet-stryker` step, plus a `PATH` addition for `$HOME/.dotnet/tools` so `dotnet stryker` resolves.
- No change to the isolation model: still no `git`, still runs as `node`, still no host credentials copied in. The `CLAUDE.md` mount is read-only, so Claude inside the sandbox cannot alter the host's copy.
- No change to `nuke`/`rebuild` semantics from the prior change.
