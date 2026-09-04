# Sandbox for running `claude --dangerously-skip-permissions` (YOLO mode) safely.
#
# Isolation model:
#   - Only /workspace (the mounted project folders) is writable project data.
#   - No `git` binary in the final image, and no host git config/credentials/SSH
#     keys are copied in — the mounted repos' .git folders are inert data that
#     nothing in the container can drive. Claude can read/edit files but cannot
#     commit, push, rewrite history, or touch remotes.
#   - Plugins are baked in at build time (stage 1, which has git only to fetch
#     marketplaces) and copied into the final git-less image (stage 2).
#
# Build:  docker build -t claude-yolo .
# Run:    claude-yolo   (see the claude-yolo script alongside this file)
FROM node:22-bookworm-slim AS builder

ARG CLAUDE_VERSION=2.1.258

# git (+ ssh, to authenticate to the private honeycombio/agent-skill and
# anthropics/claude-plugins-official repos via the build-time forwarded agent)
# is only ever present in this throwaway build stage, used purely to resolve
# plugin marketplaces. Neither git nor ssh reaches the final image.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git openssh-client ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /root/.ssh && ssh-keyscan -t ed25519 github.com >> /root/.ssh/known_hosts 2>/dev/null

RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION}

# Plugin installPaths get baked in as absolute paths, so resolve everything
# under /home/node here — the same path the final image's "node" user has —
# rather than /root, to avoid a broken path once copied over.
ENV HOME=/home/node
# Requires `docker build --ssh default` so this step can auth to GitHub via
# the host's forwarded ssh-agent (the key itself is never copied into a layer).
RUN --mount=type=ssh \
    claude plugin marketplace add git@github.com:anthropics/claude-plugins-official.git && \
    claude plugin marketplace add git@github.com:honeycombio/agent-skill.git && \
    claude plugin install honeycomb@honeycomb-plugins -y && \
    claude plugin install frontend-design@claude-plugins-official -y && \
    claude plugin install serena@claude-plugins-official -y && \
    claude plugin install context7@claude-plugins-official -y && \
    claude plugin install skill-creator@claude-plugins-official -y && \
    claude plugin install code-simplifier@claude-plugins-official -y


FROM node:22-bookworm-slim

# Set early (not just before USER node) so every root-run step below that
# writes into a user home directory — e.g. `dotnet tool install -g` — lands
# under /home/node instead of /root.
ENV HOME=/home/node

# Deliberately no `git`, `gh`, or any git-capable tool here.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl bash tini \
    && rm -rf /var/lib/apt/lists/* \
    && printf '#!/bin/sh\necho "git is disabled in this sandbox (claude-yolo container)" >&2\nexit 1\n' > /usr/local/bin/git \
    && chmod +x /usr/local/bin/git

ARG CLAUDE_VERSION=2.1.258
ARG OPENSPEC_VERSION=1.11.0
RUN npm install -g \
        @anthropic-ai/claude-code@${CLAUDE_VERSION} \
        @fission-ai/openspec@${OPENSPEC_VERSION}

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

# node:*-slim images already ship an unprivileged "node" user (uid/gid 1000).
# Plugin/marketplace state was resolved (with git) in the builder stage above;
# only the resulting config/cache files are copied here, never the git binary.
COPY --from=builder --chown=node:node /home/node/.claude /home/node/.claude
COPY --from=builder --chown=node:node /home/node/.claude.json /home/node/.claude.json

# dotnet-stryker (mutation testing), installed as a global dotnet tool.
# Deliberately unpinned — always whatever's newest on NuGet at build time,
# same floating approach already used for the .NET 11 preview channel.
RUN dotnet tool install -g dotnet-stryker
ENV PATH="${PATH}:/home/node/.dotnet/tools"

# Bake the opsx commands/skills at the user level, so they're available no
# matter which project under /workspace is mounted — not just one that has
# run `openspec init` for Claude itself. Additive: merges into the .claude
# tree copied above without touching the plugin config already there.
RUN openspec init --tools claude --force --no-animation /home/node \
    && chown -R node:node /home/node

USER node
WORKDIR /workspace

# claude and its mode flags (--dangerously-skip-permissions or not) are
# supplied by the claude-yolo script's `docker run` command, not baked in
# here, so the same image serves both "yolo" and "run" modes.
ENTRYPOINT ["tini", "--"]
