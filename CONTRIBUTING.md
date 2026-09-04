# Contributing

This project uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) for
spec-driven change management. Any change beyond a trivial fix should go
through it rather than landing as a bare PR: OpenSpec is how this repo
records the *why* and *what* behind a change, not just the diff.

## Setup

Install the OpenSpec CLI at the version this project is pinned to (see
`OPENSPEC_VERSION` in the `Dockerfile`):

```sh
npm install -g @fission-ai/openspec@1.11.0
```

The `/opsx:*` slash commands and `openspec-*` skills are already committed
in this repo for Claude Code (`.claude/`), GitHub Copilot (`.github/`),
JetBrains Junie (`.junie/`), OpenCode (`.opencode/`), and Codex (`.agents/`)
— nothing to generate after cloning. If you use a different AI coding tool,
run `openspec init --tools <your-tool>` to add it, or `openspec update` to
refresh what's there after an OpenSpec CLI upgrade.

## Workflow

This repo uses OpenSpec's `spec-driven` schema (`openspec/config.yaml`).
Each change lives under `openspec/changes/<name>/` until archived into
`openspec/specs/<capability-path>/` once implemented. A change proposal
consists of:

- `proposal.md` — why, and what's changing
- `specs/<capability-path>/spec.md` — a delta spec: the requirements this
  change adds, modifies, or removes
- `design.md` — how (when the change is non-trivial enough to warrant it)
- `tasks.md` — the implementation checklist

To start a change:

```
/opsx:propose <describe what you want to build>
```

(or `openspec new change <name>` directly, then fill in the artifacts by
hand). Once the artifacts look right, implement with `/opsx:apply`, and
once implemented and merged, fold it into the main specs with
`/opsx:archive`.

Existing capabilities live under `openspec/specs/sandbox/` — skim the
relevant ones before proposing a change to make sure you're extending
rather than contradicting them.

## Pull requests

- Reference the change name (`openspec/changes/<name>/`) in the PR
  description.
- Keep the change's `tasks.md` checkboxes up to date as you implement.
- Run `openspec validate <name>` before opening the PR.
