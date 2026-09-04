# Sandbox for running `claude --dangerously-skip-permissions` (YOLO mode) safely.
#
# Isolation model:
#   - Only /workspace (the mounted project folders) is writable project data.
#   - A real `git` binary is installed, but `/usr/local/bin/git` shadows it on
#     PATH with a wrapper that blocks `push` (and its plumbing equivalent
#     `send-pack`) to any remote, however invoked, while delegating every
#     other subcommand to the real binary at /usr/bin/git. Claude can branch,
#     stage, commit, and read history freely against a repository anywhere
#     under /workspace (including a workspace holding several repos, nested
#     or as siblings), but cannot send refs to a remote. No host git config,
#     credentials, or SSH keys are copied in regardless, so even an unblocked
#     push would have nothing to authenticate with against a private remote.
#     See openspec/changes/add-restricted-git for the full rationale.
#   - Plugin/settings/agent/skill configuration is NOT baked into the image.
#     It comes from a read-only, run-time mount of the host's `~/.claude`
#     folder (see the claude-yolo script) - the sandbox uses the same plugins
#     and settings as the host's own Claude Code. A build-time-baked opsx
#     fallback still exists below for when the host has no `~/.claude`.
#   - The host mount lands at /home/node/.claude-host, not directly on
#     /home/node/.claude: entrypoint.sh copies just the config items (CLAUDE.md,
#     settings, agents, skills, plugins, commands, ...) into the writable
#     /home/node/.claude on every start, so Claude's own runtime state there
#     (login credentials, sessions, project trust, todos) stays on the
#     persistent claude-yolo-home volume instead of being shadowed by the
#     read-only host mount. See entrypoint.sh for the full item list.
#   - entrypoint.sh also pre-accepts the workspace-trust dialog for /workspace
#     (the project mount is always at that fixed in-container path) and backfills
#     the Anthropic "frontend-design" skill if the host didn't already provide
#     one, so neither has to be repeated by hand on every fresh container/volume.
#
# Build:  docker build -t claude-yolo .
# Run:    claude-yolo   (see the claude-yolo script alongside this file)

# serena's plugin-provided MCP config (from the official marketplace) launches
# it via `uvx --from git+https://github.com/oraios/serena serena
# start-mcp-server`. Left as-is, that would re-clone and re-resolve the
# package from GitHub on every single container start, rather than once.
# This throwaway stage has a real `git` purely to pre-install serena once at
# build time; only its *output* (a self-contained tool install, no git
# involved) is copied into the final stage. It's a public repo, so — unlike
# the plugin-marketplace builder stage removed elsewhere in this change — no
# SSH/credentials are needed here either.
FROM node:22-bookworm-slim AS serena-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git python3 \
    && rm -rf /var/lib/apt/lists/*
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"
# Baked outside /home/node (see the frontend-design skill and openspec-baked
# comments further below for why: /home/node is the claude-yolo-home named
# volume, which shadows anything baked straight into it after the volume's
# first init).
ENV UV_TOOL_DIR=/opt/serena-tool/tools
ENV UV_TOOL_BIN_DIR=/opt/serena-tool/bin
# Not `--from git+URL serena` (the pattern the plugin's own `uvx` invocation
# uses): for `uvx`, the trailing name is the *entry-point/command* to run,
# but for `uv tool install` the positional name must match the package's own
# name - which this repo's pyproject.toml calls `serena-agent`, not `serena`,
# and passing `--from` alongside a mismatched name is a hard error. Installing
# the URL directly lets uv resolve the package name itself; it still exposes
# every console-script entry point the package defines (including `serena`,
# which is what entrypoint.sh actually invokes) into UV_TOOL_BIN_DIR.
RUN uv tool install git+https://github.com/oraios/serena

FROM node:22-bookworm-slim

# Set early (not just before USER node) so every root-run step below that
# writes into a user home directory — e.g. `dotnet tool install -g` — lands
# under /home/node instead of /root.
ENV HOME=/home/node

# A real `git` is installed below, but /usr/local/bin/git (earlier than
# /usr/bin/git on the default Debian PATH, same trick the old stub relied on)
# is git-wrapper.sh: a wrapper that blocks only `push` and its plumbing
# equivalent `send-pack` - to any remote, however invoked, not just one named
# `origin` - and delegates every other subcommand to the real binary at
# /usr/bin/git. See git-wrapper.sh itself for how it resolves the actual
# subcommand, and openspec/changes/add-restricted-git for the full rationale.
# safe.directory is set to `*` (not just /workspace) and a fallback identity
# is configured globally so this works with no manual setup against any
# repository anywhere under /workspace, including a workspace holding several
# repos, nested or as siblings - ownership-mismatch protection isn't a
# meaningful boundary in this single-user, single-purpose container.
# python3 is here for the `uv`/`uvx` install below, not for git-adjacent
# reasons - uv can also fetch its own Python, but a system python3 avoids
# relying on that network fetch every time a fresh container starts.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl bash tini python3 jq git \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system --add safe.directory '*' \
    && git config --system user.name 'Claude Sandbox' \
    && git config --system user.email 'sandbox@localhost'
COPY --chown=root:root git-wrapper.sh /usr/local/bin/git
RUN chmod +x /usr/local/bin/git

ARG CLAUDE_VERSION=2.1.258
ARG OPENSPEC_VERSION=1.11.0
# chown the npm global prefix to "node" (it's root-owned by default) so the
# unprivileged "node" user this container runs as can `npm install -g`
# itself at runtime, not just during this root-run build step.
RUN npm install -g \
        @anthropic-ai/claude-code@${CLAUDE_VERSION} \
        @fission-ai/openspec@${OPENSPEC_VERSION} \
    && chown -R node:node "$(npm config get prefix)"

# The image pins an exact claude-code version above; Claude Code's own
# background auto-updater would otherwise silently upgrade it on every
# start (and re-check periodically while running), drifting from that pin.
# This only disables the background check/install — `claude update` still
# works if you deliberately want to move off CLAUDE_VERSION.
ENV DISABLE_AUTOUPDATER=1

# Anthropic's official "frontend-design" skill (github.com/anthropics/skills),
# fetched at build time into a path outside /home/node so it survives the
# claude-yolo-home volume mount (which shadows everything baked in under
# /home/node after the volume's first init). entrypoint.sh copies it into
# /home/node/.claude/skills on every start, unless the host's own ~/.claude
# already provides a skill by that name.
RUN mkdir -p /opt/skills/frontend-design \
    && curl -fsSL -o /opt/skills/frontend-design/SKILL.md \
        https://raw.githubusercontent.com/anthropics/skills/main/skills/frontend-design/SKILL.md \
    && curl -fsSL -o /opt/skills/frontend-design/LICENSE.txt \
        https://raw.githubusercontent.com/anthropics/skills/main/skills/frontend-design/LICENSE.txt \
    && chown -R node:node /opt/skills

# uv/uvx: general-purpose Python tool runner, kept available at runtime for
# any plugin or ad-hoc script that wants it (e.g. `uvx <tool>`). Not what
# actually runs serena any more — see the serena-tool copy below — which
# avoids re-cloning and re-resolving serena's package from GitHub on every
# single container start.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="${PATH}:/home/node/.local/bin"

# Baked by the serena-builder stage above at a pinned version. entrypoint.sh
# rewrites the serena plugin's own .mcp.json to invoke this directly, instead
# of its default `uvx --from git+...` command, so starting serena's MCP
# server doesn't re-fetch the package from GitHub on every container start.
COPY --from=serena-builder /opt/serena-tool /opt/serena-tool
RUN chown -R node:node /opt/serena-tool
ENV PATH="${PATH}:/opt/serena-tool/bin"

# .NET SDKs (8, 9, 10 — all GA/LTS — plus the latest 11 preview) via
# Microsoft's official install script. Not apt: Microsoft's Debian feed
# only publishes dotnet-sdk packages for amd64, and this image is built
# on arm64 (Apple Silicon) too. Each GA --channel pins the major.minor
# band and floats to the latest patch within it on every build. 11 has
# no GA channel yet, so it floats further: --quality preview picks
# whatever preview build is newest at build time — deliberately, so
# rebuilds can try mounted projects against what's coming next; drop
# --quality preview once 11 reaches GA.
#
# libicu72: node:*-slim ships no ICU globalization data, and .NET aborts
# outright without it (not just for culture-aware formatting/sorting —
# `dotnet build` itself won't run). Installed rather than opting into
# DOTNET_SYSTEM_GLOBALIZATION_INVARIANT, so mounted projects behave the
# same here as on a normal dev machine.
RUN apt-get update && apt-get install -y --no-install-recommends libicu72 \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sSL -o /tmp/dotnet-install.sh https://dot.net/v1/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel 8.0 --install-dir /usr/share/dotnet \
    && /tmp/dotnet-install.sh --channel 9.0 --install-dir /usr/share/dotnet \
    && /tmp/dotnet-install.sh --channel 10.0 --install-dir /usr/share/dotnet \
    && /tmp/dotnet-install.sh --channel 11.0 --quality preview --install-dir /usr/share/dotnet \
    && rm /tmp/dotnet-install.sh
ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="${PATH}:/usr/share/dotnet"

# dotnet-stryker (mutation testing), installed as a global dotnet tool.
# Deliberately unpinned — always whatever's newest on NuGet at build time,
# same floating approach already used for the .NET 11 preview channel.
RUN dotnet tool install -g dotnet-stryker
ENV PATH="${PATH}:/home/node/.dotnet/tools"

# Bake OpenSpec's Claude Code integration — the `opsx:*` commands
# (.claude/commands/opsx) and openspec-* skills (.claude/skills) — into
# /opt, NOT into /home/node/.claude directly. /home/node is the
# claude-yolo-home named volume: Docker only seeds a brand-new *empty*
# volume from the image's content, so anything baked straight into
# /home/node/.claude would never reach an already-existing volume (the
# normal case, since the volume outlives image rebuilds) — same reasoning
# as the frontend-design skill above. entrypoint.sh backfills from here into
# /home/node/.claude on every start, filling in only what the host's own
# ~/.claude doesn't already provide.
RUN openspec init --tools claude --force --no-animation /opt/openspec-baked \
    && chown -R node:node /opt/openspec-baked

COPY --chown=root:root entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node
WORKDIR /workspace

# claude and its mode flags (--dangerously-skip-permissions or not) are
# supplied by the claude-yolo script's `docker run` command, not baked in
# here, so the same image serves both "yolo" and "run" modes. entrypoint.sh
# syncs the host-config items from /home/node/.claude-host (if mounted) into
# /home/node/.claude before exec-ing into tini.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
