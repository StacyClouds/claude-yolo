## Purpose

Lets Claude use real, local git (branching, staging, committing, history) inside the sandbox on the mounted `/workspace` repo, while structurally preventing any command from pushing refs to a remote, so commit discipline no longer has to happen entirely on the host.

## ADDED Requirements

### Requirement: Local git operations are available
The sandbox SHALL provide a real `git` binary on `PATH` capable of running local, non-network-write operations against a repository under `/workspace` — including but not limited to `status`, `add`, `commit`, `branch`, `checkout`/`switch`, `log`, `diff`, `merge`, `rebase`, `stash`, and `tag`.

#### Scenario: Creating a branch and committing
- **WHEN** `git checkout -b some-branch` followed by `git add` and `git commit` is run inside the sandbox against a repository under `/workspace`
- **THEN** the branch SHALL be created and the commit SHALL succeed, updating local repository state exactly as it would outside the sandbox

#### Scenario: Reading history and status
- **WHEN** `git status`, `git log`, or `git diff` is run inside the sandbox against a repository under `/workspace`
- **THEN** it SHALL succeed and reflect the actual working tree and history, not an error

### Requirement: Push is blocked regardless of remote or invocation
The sandbox SHALL prevent any git invocation from sending refs/objects to a remote — via `git push`, its plumbing equivalent `git send-pack`, or any other subcommand whose effect is to write to a remote — regardless of which remote name or URL is targeted (not only one literally named `origin`). A blocked attempt SHALL exit with a non-zero status and print a clear, human-readable message explaining that pushing is disabled in the sandbox, rather than silently no-opping or hanging.

#### Scenario: Push to origin is blocked
- **WHEN** `git push origin some-branch` is run inside the sandbox
- **THEN** the command SHALL fail with a non-zero exit status and print a message stating that push is disabled in the sandbox, and no refs SHALL be sent to any remote

#### Scenario: Push to a differently-named or newly-added remote is also blocked
- **WHEN** a remote is added under a name other than `origin` (e.g. `git remote add upstream <url>`) and `git push upstream some-branch` is run
- **THEN** the command SHALL be blocked the same way as a push to `origin`

#### Scenario: Push via plumbing is also blocked
- **WHEN** `git send-pack` is invoked directly instead of `git push`
- **THEN** it SHALL be blocked the same way

### Requirement: Non-push remote reads are not blocked by this capability
Read-only remote-interacting commands (e.g. `git fetch`, `git pull`, `git clone`, `git ls-remote`) SHALL NOT be blocked by this capability, since they do not write to a remote.

#### Scenario: Fetch is not blocked
- **WHEN** `git fetch` is run inside the sandbox against a reachable remote
- **THEN** it SHALL be attempted normally (network reachability and credentials are the only limiting factors, not this capability)

### Requirement: Git is usable against the mounted workspace without manual setup
The sandbox SHALL pre-configure git so that commands run against any repository located anywhere under `/workspace` — not only one checked out at the `/workspace` root — work without erroring on ownership mismatches, and so that `git commit` does not fail solely for lack of a configured identity, without requiring the user to run any setup commands first.

#### Scenario: No "dubious ownership" error on the mounted repo
- **WHEN** a git command is run against a repository located anywhere under `/workspace` (not only at the `/workspace` root itself) whose on-disk owner differs from the container's `node` user
- **THEN** git SHALL NOT refuse the operation with a "detected dubious ownership" error

#### Scenario: Commit succeeds with no identity configured in the repo
- **WHEN** `git commit` is run inside the sandbox against a repository that has no `user.name`/`user.email` set in its own local config
- **THEN** the commit SHALL succeed using a sandbox-provided fallback identity, rather than failing with an identity error

### Requirement: Correct repository is used in a multi-repo workspace
When `/workspace` contains more than one git repository (nested, or as sibling directories), a git command run with its working directory inside one of those repositories SHALL operate on that repository only, using git's standard repository discovery (searching upward from the current directory for the nearest `.git`) — never a different repository elsewhere under `/workspace`.

#### Scenario: Sibling repos stay independent
- **WHEN** `/workspace` contains two independent repositories as sibling directories, and a git command (e.g. `git status`, `git commit`) is run with the working directory inside one of them
- **THEN** the command SHALL report and act on that repository's own state only, unaffected by the other sibling repository

#### Scenario: Nested repo takes precedence over its parent
- **WHEN** a repository under `/workspace` contains another independent git repository nested inside one of its subdirectories, and a git command is run with the working directory inside the nested repository
- **THEN** the command SHALL operate on the nested repository, not the outer one
