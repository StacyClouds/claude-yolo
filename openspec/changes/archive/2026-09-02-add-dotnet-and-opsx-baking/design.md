## Context

Two independent capabilities land in the same place: the final stage of `Dockerfile`. See proposal.md for motivation. Today that stage is `node:22-bookworm-slim` with no `git`, installs `claude-code` + `openspec` via npm, copies baked plugin config (`/home/node/.claude`, `/home/node/.claude.json`) from the builder stage, then switches to the unprivileged `node` user before setting `WORKDIR /workspace`.

## Goals / Non-Goals

**Goals:**
- Reliable, repeatable install of .NET SDKs 8, 9, 10, and the latest 11 preview, working on whatever architecture the image is built on (this repo is built and run on Apple Silicon, i.e. arm64).
- opsx commands/skills available no matter which sibling project under `/workspace` is mounted, without depending on that project's own scaffolding.
- No disruption to the existing isolation model (no `git`, no host credentials, unprivileged runtime user, existing plugin baking untouched).

**Non-Goals:**
- Pinning .NET 11 to a specific preview build — it intentionally floats to whatever's newest at build time; re-pin to a stable band once it's GA.
- Cross-building for an architecture other than the host's.
- Changes to `claude-yolo` (the run script) or the bind-mount layout.
- Reworking the builder/final two-stage split.

## Decisions

**1. Install .NET via Microsoft's `dotnet-install.sh` script, not apt.**
Originally planned as apt via Microsoft's Debian 12 feed, since all three needed versions (8, 9, 10) are GA/LTS. That failed at build time: Microsoft's `packages.microsoft.com/debian/12/prod` feed only publishes `dotnet-sdk-*` packages for amd64 — there is no arm64 build in that repo, so `apt-get install dotnet-sdk-8.0` fails outright on this arm64 host with "Unable to locate package". `dotnet-install.sh` fetches the correct architecture's binary tarball directly and works uniformly on amd64 and arm64, so it replaces apt for all three versions (not just previews, as originally scoped for a hypothetical .NET 11).

**2. Channel arguments to `dotnet-install.sh`, still no version-pinning ARGs.**
Each GA version is installed with `--channel 8.0` / `9.0` / `10.0` (GA quality, the default), which — like the apt package names originally planned — pins the major.minor band while floating to the latest patch at build time. Same rationale as before: patches are routinely security fixes, and the image rebuilds fresh on every `claude-yolo` invocation.

.NET 11 is installed the same way but with `--channel 11.0 --quality preview`, since no GA build exists yet. This floats further than the other three: it moves to whatever the newest preview is at build time, not just the newest patch within a fixed band, and that band itself will shift as 11 moves through preview → RC → GA. That instability is inherent to tracking a pre-release and is accepted deliberately — the point of including it is to try mounted projects against what's coming, not to pin a reproducible version. Once 11 reaches GA, drop `--quality preview` so it behaves like the other three.

**3. `DOTNET_ROOT` and `PATH` are set explicitly.**
`dotnet-install.sh` installs into `/usr/share/dotnet` (via `--install-dir`) by default but does not put anything on `PATH` itself. `ENV DOTNET_ROOT=/usr/share/dotnet` and appending `/usr/share/dotnet` to `PATH` are required for the `dotnet` command to resolve at all, for both the root install step's own sanity-checking and the `node` user at runtime.

**4. Install `libicu72` alongside the SDKs.**
Discovered during verification: `node:22-bookworm-slim` ships no ICU globalization data, and .NET aborts outright without it ("Couldn't find a valid ICU package installed on the system") — not just for culture-specific formatting, but for basic commands like `dotnet build`. The alternative, `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`, avoids the package but forces every .NET process in the sandbox into invariant-culture mode (no locale-aware formatting/comparison/sorting), which could make mounted projects behave differently inside the sandbox than they do on a real dev machine. Since this sandbox exists to build/run arbitrary mounted .NET projects, matching normal runtime behavior (full ICU) is preferred over the smaller, behavior-limited alternative.

**5. Bake opsx by re-running the generator (`openspec init --tools claude --force --no-animation /home/node`) at build time, not by `COPY`-ing this repo's own `.claude/`.**
Verified experimentally: re-running `openspec init` against a directory that already has unrelated `.claude/` content (a settings file, unrelated commands) merges additively — it only touches `.claude/commands/opsx/*` and `.claude/skills/openspec-*`, leaving everything else alone. Regenerating also keeps the baked commands/skills in lockstep with the already-pinned `ARG OPENSPEC_VERSION`, rather than freezing a snapshot of this specific repo's `.claude/` (which is scoped to editing claude-yolo itself, could drift, and isn't what the generator for a given OpenSpec version would necessarily produce). It also respects the existing `.dockerignore` (`**`), which deliberately keeps this repo's project scaffolding out of the build context — regenerating at build time doesn't need that boundary opened.

**6. Ordering: dotnet install can go anywhere before `USER node`; the opsx bake step must run *after* the plugin `COPY`, followed by a `chown`.**
The plugin config only exists in the final stage after its `COPY --from=builder` step. Running `openspec init` afterward, merging into that already-populated `/home/node/.claude`, is exactly the sequence tested above. Both the dotnet install and the opsx bake step run as root (before `USER node` is set), so a `chown -R node:node /home/node` is needed after the opsx bake step, mirroring the `--chown=node:node` already used on the plugin `COPY`.

## Risks / Trade-offs

- **Image size grows (~3-4GB for four SDKs) → slower build/pull.** No mitigation attempted; this is a local dev sandbox rebuilt on demand, not a distributed artifact, so the trade-off is accepted as-is.
- **Root-owned files if the `chown` step is skipped or misplaced** → the `node` user could fail to write under its own home at runtime. Mitigated by placing `chown -R node:node /home/node` immediately after the opsx bake step, before `USER node`.
- **`dotnet-install.sh` is fetched over the network at build time from `dot.net`, outside Debian's own trust chain** → the build fails loudly if that endpoint is unreachable or the script changes incompatibly, rather than silently succeeding with the wrong toolchain. Acceptable: failure is visible immediately, and this isn't a CI-gated release path. (This trades away the apt-based supply chain, but apt turned out not to be viable on arm64 at all — see Decision 1.)
- **The .NET 11 preview is inherently unstable** — a rebuild can silently pick up a newer, behaviorally different preview build with no version bump anywhere in the Dockerfile. Accepted deliberately (see Decision 2); if reproducibility across rebuilds ever matters, pin with `--version <exact>` instead of `--channel 11.0 --quality preview`.

## Migration Plan

This is a locally-built sandbox image, not a deployed service. "Migration" is just the next `claude-yolo` invocation, which always runs `docker build` before `docker run`. No data migration is needed — the `claude-yolo-home` named volume (persisted Claude login) is untouched by either change. Rollback is reverting the `Dockerfile` edits and rebuilding.
