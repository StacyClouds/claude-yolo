## Why

The sandbox image can't build or run .NET projects today (no `dotnet` at all), and the opsx commands/openspec skills are only usable when the *mounted* project itself happens to have run `openspec init` for Claude. Since `claude-yolo` mounts the whole `stacyclouds` parent folder as `/workspace`, most sibling projects don't have that scaffolding, so opsx is unavailable against them even though it's genuinely useful.

## What Changes

- Bake the .NET SDKs for versions 8, 9, and 10 into the final image via Microsoft's official `dotnet-install.sh` script (Microsoft's apt feed for Debian doesn't publish `dotnet-sdk` packages for arm64, which this image builds as), so mounted .NET projects can be built and tested inside the sandbox.
- Also bake the latest .NET 11 **preview** build (`--channel 11.0 --quality preview`), since 11 isn't GA yet. Unlike 8/9/10, this one floats to whatever preview is newest at build time rather than pinning to a stable band — it will move under the same channel as 11 progresses through preview/RC, and again once it reaches GA.
- Bake the opsx slash commands (`/opsx:propose`, `/opsx:explore`, `/opsx:apply`, `/opsx:archive`, `/opsx:sync`) and the corresponding openspec skills into the image at the **user** level (`/home/node/.claude`), via `openspec init --tools claude --force --no-animation /home/node` at build time. This makes opsx available regardless of which sibling project under `/workspace` is being worked on, instead of depending on that project's own `.claude/` scaffolding.
- Both changes are confined to the final stage of the `Dockerfile`. The `claude-yolo` run script is unaffected.

## Capabilities

### New Capabilities
- `sandbox/dotnet-toolchain`: the built sandbox image provides .NET SDKs 8, 9, 10, and the latest 11 preview, usable against any mounted project.
- `sandbox/opsx-tooling`: the built sandbox image provides the opsx commands and openspec skills at the user level, independent of whether the mounted project has its own openspec scaffolding.

### Modified Capabilities
(none)

## Impact

- `Dockerfile` (final stage only): new `dotnet-install.sh`-based SDK install for channels 8.0/9.0/10.0 plus the 11.0 preview channel, plus `DOTNET_ROOT`/`PATH` setup; new `RUN openspec init --tools claude --force --no-animation /home/node` step plus an ownership fix, placed after the existing plugin `COPY` and before `USER node`.
- Image size grows noticeably (roughly 700MB-1GB per SDK, so +3-4GB with 11 included) and build time increases accordingly.
- No change to the isolation model: still no `git` binary, still runs as the unprivileged `node` user, still no host credentials copied in.
- No change to `claude-yolo` (the run script) or to how `/workspace` is mounted.
- Follow-up (not in this change): once .NET 11 reaches GA, drop `--quality preview` so it pins to a stable band like the other three.
