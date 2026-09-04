## Context

Today `/usr/local/bin/git` in the final image (Dockerfile:77-81) is a one-line stub that always errors, and no real `git` package is installed in the final stage at all — only the throwaway `serena-builder` stage has one, purely to pre-install `serena` at build time (its output, not `git` itself, is copied forward). `/workspace` is a host bind mount, so the files' on-disk UID/GID may not match the container's `node` user, which is exactly the shape of mismatch git's `safe.directory` check exists to flag. See proposal.md - Why for the motivation.

## Goals / Non-Goals

**Goals:**
- A real `git` on `PATH` that behaves normally for every local operation.
- `push` (and equivalent plumbing) structurally blocked, independent of remote name, in a way that can't be routed around by config alone (e.g. renaming the remote, adding a second remote).
- Zero manual setup for the common case: cloning/mounting a repo and immediately being able to `status`/`commit`.

**Non-Goals:**
- Defending against a deliberately adversarial attempt to defeat the block from inside the container (e.g. locating and calling the real `git` binary directly by path). The sandbox's threat model is Claude acting under normal instructions, not a hostile actor with shell access trying to escape a sandboxing measure it knows about — the existing "no git at all" stub had the same property (nothing stopped hand-writing raw git-protocol bytes over a socket either).
- Blocking network egress in general (fetch/clone/pull stay allowed) — see spec's "Non-push remote reads are not blocked" requirement.
- Any change to credential handling: the sandbox still copies in no host git config, SSH keys, or credentials (Dockerfile header, README "No host git config, credentials, or SSH keys are copied in" — unchanged by this proposal).

## Decisions

**Wrapper script shadowing the real binary on `PATH`, rather than a git hook or transport-level block.**
Install real `git` via `apt-get install git`, which lands at `/usr/bin/git`. Keep the existing stub's file location, `/usr/local/bin/git`, but replace its content with a wrapper: inspect the first non-option argument, and if it resolves to `push` or `send-pack`, print an error to stderr and exit non-zero; otherwise `exec /usr/bin/git "$@"`. `/usr/local/bin` precedes `/usr/bin` in the default Debian `PATH`, so the wrapper wins without needing to move or rename the real binary — same mechanism the current stub already relies on.
- Alternative considered: a `pre-push` git hook. Rejected — hooks are per-repository (`.git/hooks`), so anyone can point git at a fresh `git init` or a repo cloned without the hook and push freely; it also doesn't cover `git send-pack` called directly.
- Alternative considered: block at the network layer (e.g. iptables dropping outbound to git remotes). Rejected — remotes aren't a fixed, enumerable set of hosts, network tooling isn't otherwise part of this image, and it would also break the already-desired `fetch`/`pull`/`clone`.
- Alternative considered: patch git's own source/config to disable the push transport. Rejected — no supported git config flag disables push globally per-installation; would mean carrying a patched build.

**Matching on the resolved subcommand, not a literal `push` string match, and independent of remote name.**
The wrapper must treat `git -C foo push`, `git --git-dir=... push`, and similar option-prefixed forms the same as bare `git push` — it should scan args for the first token that isn't a recognized global option/its value, rather than only checking `argv[1]`. It must not special-case the string `origin`: any remote argument (or none, i.e. the configured default) is blocked identically, since restricting only a remote literally named `origin` is trivial to route around by renaming or adding a remote (see spec scenario "Push to a differently-named or newly-added remote is also blocked").

**`safe.directory = *` (not scoped to the literal `/workspace` path), plus a fallback identity, set at the system/global git config level (not per-repo).**
A workspace can contain more than one repository — nested, or several as sibling folders — and whichever one a command is run from (or against, via `-C`) must work without per-repo setup. Scoping `safe.directory` to the single literal path `/workspace` only covers a repo checked out at that exact root; it would leave every other repo under it (or one added after the container starts) still erroring on "detected dubious ownership". Use `git config --system --add safe.directory '*'` instead, which trusts every repository regardless of path, and set a global fallback `user.name`/`user.email` (e.g. `Claude Sandbox <sandbox@localhost>`), via `git config --system` at image build time. Local repo config still takes precedence over the system default, so this is purely a fallback, not an override. This doesn't touch git's own repository discovery (walking up from the current directory to the nearest `.git`) — that's unmodified stock git behavior, so running a command from inside a given repo's directory already operates on that repo, never a sibling or parent one.
- Build-time (`Dockerfile`) vs. runtime (`entrypoint.sh`): build-time is simpler and sufficient here, since neither setting depends on anything only known at container start. Put it in the `Dockerfile` alongside the git install.

## Risks / Trade-offs

- [A user could still directly invoke `/usr/bin/git` by full path, bypassing the wrapper entirely] → Accepted (see Non-Goals) — this protects against the normal-instruction-following case the same way the current stub does, not a deliberate bypass attempt. Documented explicitly in the README so it isn't assumed to be adversarially secure.
- [`safe.directory = *` trusts every repository path in the container, not just ones under `/workspace`] → Accepted: the sandbox is single-user (only the `node` user ever runs git here), so the ownership-mismatch scenario `safe.directory` guards against (a different, potentially malicious user owning files in a shared multi-user system) doesn't apply here — the only mismatch this sandbox ever sees is the intentional one between the bind-mounted `/workspace` and the container's `node` UID.
- [Wrapper's argument-parsing to find "the subcommand" could miscategorize an unusual invocation and either wrongly block a safe command or wrongly let a push through] → Mitigate by keeping the matching conservative: recognize the small, fixed set of global options git itself defines (`-C <path>`, `--git-dir=`, `-c <key=val>`, etc.) rather than trying to fully replicate git's own argument grammar, and fail closed (block) on anything unrecognized that could plausibly be a push variant.

## Migration Plan

No data migration. This is an image/tooling change: `claude-yolo rebuild` picks it up (per README, `run`/`yolo` reuse an existing image and never rebuild automatically). No rollback concerns beyond reverting the Dockerfile change and rebuilding — no state is created that outlives a container run, since git identity/config is baked into the image layer, not the persisted `claude-yolo-home` volume.
