## Context

See proposal.md - Why. `claude-yolo`'s current parsing (`claude-yolo:59-122` as of this change) checks for a leading `--workspace <path>` first, then matches the next argument against the subcommand keywords (`rebuild`, `nuke`, `run`, `yolo`), then forwards whatever is left straight to `claude` for `run`/`yolo` modes. `nuke` has its own private flag, `--preserve-token`, parsed the same way inside its own branch.

## Goals / Non-Goals

**Goals:**
- A bare positional argument that isn't a recognized keyword is treated as a workspace-path override attempt, validated the same way `--workspace` already is, so a typo or mismatched intent fails loudly instead of being silently forwarded to `claude`.
- Arguments meant for `claude` are unambiguous: only reachable via `--`.
- `--help`/`-h` works with zero preconditions (no Docker needed).

**Non-Goals:**
- Removing `--workspace <path>`. It keeps working unchanged as an explicit, unambiguous spelling — this change only adds the bare-positional shorthand alongside it, since nothing asked for its removal and existing docs/muscle-memory use it.
- Touching `opencode-yolo`. It's a separate script covered by its own capability (`sandbox/opencode-yolo-cli`); this change is scoped to `claude-yolo` only.
- Validating or erroring on `--` arguments given to `rebuild`/`nuke`, which don't forward anything to `claude`. They're simply unused, same as today.

## Decisions

- **`--` is the pass-through separator**, not a named flag like `--claude-arg`. It's the standard convention (`git -- <pathspec>`, `docker run img -- cmd`) and the only option that forwards claude's own `-`-prefixed flags without needing to repeat a wrapper flag per argument.
- **Subcommand keywords always win over the workspace-path check.** `claude-yolo run` always means the `run` subcommand, never an attempt to mount a directory named `run`. A directory with one of those four exact names needs an explicit form (`./run`, or `--workspace run`) to be used as a workspace path. This is simpler to reason about than "a path wins if it exists on disk," whose behavior would depend on what happens to be on disk at invocation time.
- **An unmatched leftover argument is a hard error, not a silent forward.** This is the actual fix for the ambiguity in proposal.md - Why: `claude-yolo .` now fails clearly (`.` isn't a valid-looking anything once keywords and `--workspace` are ruled out... actually `.` *is* a valid directory, so `claude-yolo .` now means "mount `.` as the workspace" — see below) rather than quietly becoming a `claude` argument.
- **Test harness: a hand-rolled POSIX `sh` test script**, not bats-core. The repo has zero test-framework dependencies today (only ShellCheck/Hadolint linting); a plain script with a fake `docker` stub on `PATH` (capturing invocations to a log file for assertions) covers this change's scenarios without adding a new tool contributors or CI need to install.

- **One unified error message for an unrecognized bare argument**, covering both "not an existing directory" and "if this was meant for claude, use `--`" in the same sentence, rather than two different messages depending on whether a subcommand preceded the bad argument. `claude-yolo "fix the bug"` (no subcommand) hits the workspace-path check before the `--` check ever runs — there's no subcommand yet to dispatch into a `run`/`yolo` branch that could apply a separate "`--` required" error — so the single message has to carry both explanations to stay accurate and still be helpful.

## Risks / Trade-offs

- [Breaking change: any existing `claude-yolo run "prompt text"` invocation (no `--`) now fails instead of working] → Accepted and intended — proposal.md marks it **BREAKING**. The new error message names the offending argument and points at `--`, so the fix is immediate and obvious.
- [`claude-yolo .` now means "mount the current directory as the workspace" instead of "pass `.` to claude"] → This is the deliberate resolution of the ambiguity that motivated this change; documented in `--help` and the README.
- [Hand-rolled test harness has a smaller feature set than bats-core (no built-in TAP output, setup/teardown helpers, etc.)] → Acceptable for this change's scope; revisit bats-core later if script test coverage grows enough to justify the new dependency.
