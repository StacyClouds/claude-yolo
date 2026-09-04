## Why

The sandbox currently has no working `git` at all — `/usr/local/bin/git` is a stub that errors out — so Claude can read a mounted repo's history but can't commit its own work inside the container. That pushes all commit discipline back onto the host, which is inconvenient for normal use (branching, staging, committing as work progresses) and isn't actually necessary for the sandbox's safety goal: the risk this design protects against is Claude pushing changes somewhere outside the mounted folder (rewriting shared/remote history, leaking code to a remote, or acting on the host's credentials), not local commits inside `/workspace`. A real but network-write-restricted `git` gets the convenience back without reopening that risk.

## What Changes

- Install a real `git` binary in the sandbox image (currently absent entirely).
- Replace the current "no git" stub with a wrapper that shadows the real binary on `PATH`: it delegates every subcommand to real `git` except `push` (and the equivalent plumbing command `send-pack`), which it refuses with a clear error, regardless of which remote is targeted — not just a remote literally named `origin`.
- Pre-configure `safe.directory` to trust every repository (not only one checked out at the `/workspace` root) so git works from any repo directory under `/workspace` — including a workspace containing several repos, nested or as siblings — despite a possible UID mismatch between host and container; set a fallback global `user.name`/`user.email` so `git commit` doesn't fail for lack of identity when the mounted repo has none configured.
- Update the README and the Dockerfile's own header comment, which currently document "no git binary" and "cannot commit, push, rewrite history" as the isolation model, to describe the new restricted-git behavior instead.

**BREAKING**: none for existing users — this only adds capability that previously errored out (git was fully absent before).

## Capabilities

### New Capabilities
- `sandbox/git-access`: local git usage (branch, commit, status, log, diff, merge, etc.) is available inside the sandbox, correctly scoped to whichever repository the current directory belongs to when a workspace holds more than one, while `push` (to any remote, via any command that sends refs to one) is structurally blocked.

### Modified Capabilities
(none — no existing capability's requirements change; the prior "no git binary" behavior was implementation detail, not a documented capability requirement)

## Impact

- `Dockerfile`: replace the `git`-stub `RUN` step with a real `git` install, the `safe.directory`/identity git config, and a `COPY` of a new `git-wrapper.sh` script installed ahead of the real binary on `PATH`.
- New file `git-wrapper.sh` (repo root, alongside `entrypoint.sh`): the push/`send-pack`-blocking wrapper itself.
- `README.md`: update the "no git binary" isolation-model bullet and the "what this sandbox does not protect against" section to reflect that local git now works but push is blocked.
- No changes to `entrypoint.sh`, `claude-yolo`, or any other capability's behavior.
