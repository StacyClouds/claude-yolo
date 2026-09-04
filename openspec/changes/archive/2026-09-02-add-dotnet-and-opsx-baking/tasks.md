## 1. .NET toolchain

- [x] 1.1 Add Microsoft's `dotnet-install.sh` fetch to the `Dockerfile` final stage and run it for channels 8.0, 9.0, and 10.0 into `/usr/share/dotnet`, and verify `docker build` completes this step without error (apt is not viable here: Microsoft's Debian feed has no arm64 `dotnet-sdk` packages)
- [x] 1.2 Set `ENV DOTNET_ROOT=/usr/share/dotnet` and add it to `PATH` in the final stage, and verify the build completes
- [x] 1.3 Install `libicu72` in the final stage (the `node:22-bookworm-slim` base has no ICU data, which crashes `dotnet` outright — discovered when task 1.5 first failed) and verify the build completes
- [x] 1.4 Rebuild the image and verify `dotnet --list-sdks` run inside the container lists an 8.x, a 9.x, and a 10.x entry
- [x] 1.5 Verify `dotnet build`/`dotnet --info` runs inside the running container as the `node` user with no permission errors and no ICU/globalization errors
- [x] 1.6 Add a `dotnet-install.sh --channel 11.0 --quality preview --install-dir /usr/share/dotnet` call alongside the 8/9/10 installs and verify `docker build` completes this step without error
- [x] 1.7 Rebuild the image and verify `dotnet --list-sdks` lists an 11.x entry in addition to 8.x/9.x/10.x
- [x] 1.8 Verify a project can be built against the 11 preview (`dotnet build` with `TargetFramework` set to the matching `net11.0` moniker) as the `node` user, with no permission or ICU errors

## 2. opsx baking

- [x] 2.1 Add `RUN openspec init --tools claude --force --no-animation /home/node` to the final stage, placed after the plugin `COPY --from=builder .../.claude` step and before `USER node`
- [x] 2.2 Add `chown -R node:node /home/node` immediately after that step and verify the build completes
- [x] 2.3 Rebuild and verify `/home/node/.claude/commands/opsx/*.md` and `/home/node/.claude/skills/openspec-*/SKILL.md` exist inside the image, owned by `node`
- [x] 2.4 Verify the plugin config already baked under `/home/node/.claude` (e.g. installed plugin entries) is still intact after the bake step

## 3. Integration verification

- [x] 3.1 Run `claude-yolo` mounted against a sibling project with no local `.claude/commands/opsx` of its own and confirm `/opsx:explore` (or another opsx command) is available
- [x] 3.2 Confirm no regression to the existing isolation model: `git` inside the container still prints "git is disabled" and exits non-zero, and the container still runs as the `node` user, not root
