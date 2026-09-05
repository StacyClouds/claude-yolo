# claude-yolo

[![Lint](https://github.com/StacyClouds/claude-yolo/actions/workflows/lint.yml/badge.svg)](https://github.com/StacyClouds/claude-yolo/actions/workflows/lint.yml)

A Docker sandbox for running Claude Code with `--dangerously-skip-permissions`
(YOLO mode) safely, so Claude can act on a project without prompting for
every file edit or command.

## Why this exists

YOLO mode skips Claude Code's normal per-action permission prompts. That's
fine for throwaway edits inside a project folder, but risky if Claude can
also touch your host machine, push to your remotes, or use your credentials.
This sandbox removes those risks structurally rather than by relying on
Claude's own restraint:

- Only the mounted project folder (`/workspace`) is writable project data.
- Git works locally, but **`push` is disabled**. A wrapper shadows the real
  `git` binary and blocks `push` (and its plumbing equivalent `send-pack`) to
  any remote, however invoked — Claude can branch, stage, commit, and read
  history against any repo under `/workspace`, but can't send refs anywhere.
- No host git config, credentials, or SSH keys are copied in, so even an
  unblocked push would have nothing to authenticate with against a private
  remote.
- Nothing outside the container is reachable.

Because of this, it's safe to let Claude run unattended with permissions
skipped — the worst it can do is make a mess of (or bad commits in) the
mounted folder, and since nothing was ever pushed, that's always recoverable
by resetting to a point before the session, from the host side if needed.

## Requirements

- Docker
- A working `claude` CLI login (you'll authenticate once inside the sandbox;
  see [Login persistence](#login-persistence-and-config-from-your-host)
  below for how that survives across runs)

## Installation

### macOS / Linux / WSL / Git Bash

Symlink the `claude-yolo` script onto your `PATH`, e.g.:

```sh
ln -s /path/to/this/repo/claude-yolo ~/.local/bin/claude-yolo
```

The script resolves its own symlink, so it finds the Dockerfile regardless
of where it's called from.

### Windows (PowerShell)

If you don't use WSL or Git Bash, `claude-yolo.ps1` is a native PowerShell
port of the same script, for Docker Desktop on Windows. Requirements:

- Docker Desktop, running Linux containers (the default)
- Windows PowerShell 5.1 (built into Windows 10/11) or PowerShell 7+ — both
  are supported

`claude-yolo.ps1` doesn't follow symlinks (see `openspec/changes/archive/`
for why), so instead of symlinking it onto `PATH`, either:

- Add this repo's folder to your `PATH` and call it as `claude-yolo.ps1
  [args...]`, or
- Add a function to your PowerShell profile (`$PROFILE`) that calls it by
  full path:
  ```powershell
  function claude-yolo { & "C:\path\to\this\repo\claude-yolo.ps1" @args }
  ```

The first time you run it, Windows may block the downloaded/cloned script
as unsigned. Unblock it once with the built-in `Unblock-File` cmdlet —
`Unblock-File .\claude-yolo.ps1` — or invoke it directly with
`powershell -ExecutionPolicy Bypass -File .\claude-yolo.ps1 ...`, same as
you'd set the executable bit on `claude-yolo` elsewhere.

Everywhere below, replace `claude-yolo` with `claude-yolo.ps1` — every
subcommand, flag, and pass-through argument works identically.

## Usage

```
claude-yolo [--workspace <path>] [subcommand] [args...]
```

| Subcommand | Behaviour |
|---|---|
| *(none)* | Same as `yolo`. |
| `yolo [args...]` | Build the image if it doesn't exist yet, then run `claude --dangerously-skip-permissions [args...]` inside it. |
| `run [args...]` | Same, but launches plain `claude [args...]` — normal permission prompts apply. Useful when you want the sandbox's tooling/isolation without skipping permissions. |
| `rebuild` | Force a fresh `docker build`. Doesn't start a container. Run this after editing the `Dockerfile`, or to pick up newer floating package versions (e.g. a .NET SDK patch) — `run`/`yolo` reuse an existing image and never rebuild automatically. |
| `nuke` | Removes the built image **and** the `claude-yolo-home` volume (your persisted login), after confirmation. This is the only thing that clears a saved login. |

Any arguments after the subcommand (or after `claude-yolo` itself, in the
no-args default) are passed straight through to `claude`, e.g.:

```sh
claude-yolo "fix the failing test in Foo.cs"
claude-yolo run "review this PR"
```

### Choosing the workspace folder

By default, the folder mounted as `/workspace` is this script's own parent
directory. Point it at a different project with `--workspace`, which must
come *before* the subcommand:

```sh
claude-yolo --workspace ~/code/some-other-project yolo
```

No rebuild is needed — this is just a different `docker run -v` argument
each time. You can run multiple `claude-yolo` invocations concurrently
against different `--workspace` paths; each gets its own container and
`/workspace`, while all of them share the same persisted login (see below).

## Login persistence and config from your host

Every `claude-yolo` invocation starts a fresh, disposable container
(`docker run --rm`) — nothing about the *container* itself is long-lived.
Two separate mechanisms make it still feel like a continuous setup:

### 1. Login and session state (`claude-yolo-home` volume)

`/home/node` inside the container is backed by a named Docker volume,
`claude-yolo-home`, that persists across every run. This is where Claude
Code keeps things like:

- your login credentials
- session/conversation history
- project trust decisions (has this folder been approved?)
- shell snapshots, todos

Because it's a volume rather than part of the disposable container, you log
in once and stay logged in across every future `claude-yolo` run — until you
explicitly run `claude-yolo nuke`, which is the only thing that removes it.

### 2. Your global Claude Code config, from the host

If you have a `~/.claude` folder on your host machine (settings, agents,
skills, plugins, custom commands, `CLAUDE.md`, etc.), it's mounted **read-only**
into the container at `/home/node/.claude-host`. On every container start,
before Claude launches, `entrypoint.sh` copies just the known config items
out of that mount into the container's writable `/home/node/.claude`:

```
CLAUDE.md, settings.json, settings.local.json, keybindings.json,
statusline-command.sh, statusline-command.ps1,
agents/, commands/, skills/, plugins/, rules/, workflows/
```

Directory items (`agents/`, `skills/`, `plugins/`, etc.) are **merged** —
your host's copy overlays what's already there, so anything you installed
from *inside* a running container (e.g. `claude plugin install`, or a skill
dropped straight into `~/.claude/skills`) still survives to the next
container, even if it isn't on your host. File items (`settings.json`, etc.)
are fully replaced from your host's copy each time.

Nothing else under `/home/node/.claude` is touched by this sync — that's
what lets your login/session state (mechanism 1, above) live at the same
path without being wiped by it. The mount is read-only, so nothing Claude
does inside the sandbox can ever modify your actual host `~/.claude` folder;
edit it on the host and the change shows up on the *next* container start,
no rebuild required.

If your host has no `~/.claude` folder at all, none of this applies — the
sandbox just starts with no plugins/settings/agents/skills sourced from a
host, and no config-sync step runs. A build-time-baked fallback (see
[Built-in tooling](#built-in-tooling) below) still provides `opsx`
commands/skills and the `frontend-design` skill in that case.

### 3. YOLO mode's confirmation dialog is pre-accepted

Claude Code normally asks you to confirm a "Bypass Permissions mode" warning
the first time you run with `--dangerously-skip-permissions`, and remembers
your answer in `settings.json`. Since step 2 above replaces `settings.json`
from your host's copy on every start (and your host's own Claude Code
config has no reason to have accepted *this sandbox's* dialog), that
acceptance would otherwise be silently wiped every single run. `entrypoint.sh`
forces it back on after the sync, so `claude-yolo yolo` never makes you
click through that dialog again — this happens unconditionally, so it's true
even for a fresh container with no host `~/.claude` at all.

## Built-in tooling

Baked into the image, on top of a pinned version of Claude Code itself:

- **OpenSpec CLI** (`openspec`) — globally installed, so `openspec init`
  works in any mounted project, independent of anything baked into
  `~/.claude`.
- **`opsx:*` commands and `openspec-*` skills** — baked as a fallback under
  `/opt/openspec-baked`, backfilled into `~/.claude` on every start *only
  for names your host's own `~/.claude` doesn't already provide*. If your
  host has an unrelated `~/.claude` folder that lacks these, you still get
  them; if your host's `~/.claude` has its own version, that wins.
- **`frontend-design` skill** — same backfill treatment, from
  `/opt/skills`.
- **Python 3 + `uv`/`uvx`** — a general-purpose Python tool runner, available
  at runtime for any plugin or script that wants it.
- **`serena`, pre-installed at build time** — the `serena` plugin (if your
  host's `~/.claude` has it configured) normally launches its MCP server via
  `uvx --from git+https://github.com/oraios/serena serena start-mcp-server`,
  which would otherwise re-fetch and resolve the package from GitHub on every
  single container start. A throwaway build stage with a real `git` (a public
  repo, so no SSH/credentials needed) installs serena once at image build time
  into `/opt/serena-tool` instead; `entrypoint.sh` rewrites serena's plugin
  config on every start to call that pre-installed binary directly rather than
  its default `git+` invocation. One consequence: serena's version is pinned
  to whatever was fetched at the last `claude-yolo rebuild`, rather than
  always tracking the latest commit.
- **.NET SDKs 8, 9, 10, and the latest 11 preview**, plus `dotnet-stryker`
  (mutation testing) as a global `dotnet` tool — usable by the unprivileged
  `node` user the container runs as.
- **A writable npm global prefix** — `npm install -g` works at runtime as
  the `node` user, not just during the image build.

## What this sandbox does *not* protect against

- **Arbitrary damage inside `/workspace`.** Claude can edit, delete, or commit
  over any file in the mounted project — commits made inside the container are
  real and local. The mitigation is still git, ultimately on the host: since
  push is disabled inside the sandbox, recovering from an unwanted change means
  resetting to a commit from before the session (or from the host's own
  clone/copy) rather than reverting a push.
- **Someone locating and calling the real git binary directly.** The push
  block is a wrapper around `git` on `PATH`, not a kernel- or network-level
  restriction — it stops normal use from pushing, not a deliberate attempt to
  bypass it from inside the container.
- **A host with no `~/.claude`.** You get zero plugins configured (no
  `serena`, `context7`, etc.) beyond the `opsx`/`frontend-design` fallback —
  there's nothing to source them from.
- **npm permission issues in mounted projects.** The npm fix here only
  covers npm's own global install location; it doesn't address
  host-UID-vs-container-UID mismatches for files under `/workspace` itself.

## Related

See `openspec/` in this repo for the change history behind this sandbox's
design decisions (why the host-config mount works the way it does, why the
`builder` stage was removed, etc.) — most recently
`openspec/changes/fix-sandbox-npm-serena-host-claude/`.
