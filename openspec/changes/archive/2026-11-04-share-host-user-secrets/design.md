## Context

`claude-yolo` assembles one `docker run` command in `run_container`, with optional pieces added by `${VAR:+...}`. Tests in `test/claude-yolo.test.sh` stub `docker` and inspect the logged arguments. `/home/node` is a named volume; bind mounts below it are allowed and shadow the same path in the volume. The .NET user-secrets store on macOS and Linux is `~/.microsoft/usersecrets/<id>/secrets.json`, where the id comes from `<UserSecretsId>` in the project file.

## Goals / Non-Goals

**Goals:**
- Apps in the container read their host secrets with no change to the app.
- The agent can read only the secrets of the projects in the mounted workspace.

**Non-Goals:**
- Windows hosts (`%APPDATA%\Microsoft\UserSecrets`).
- Writing secrets from the container; the mount is read-only, so `dotnet user-secrets set` fails there.
- A hard block on the agent. Agent and runtime share one user (`node`, with passwordless `sudo`), and a process's environment is readable by the same user, so file permissions, a second user or environment variables cannot separate them. A separate container or user for the app would need the agent not to start the app, which defeats the purpose.
- Rewriting values such as `localhost` to `host.docker.internal`; apps override those with environment variables, as described by the host-services skill.

## Decisions

- **Opt-in flag** over default-on: the agent runs without permission prompts and has network access, so exposure should be a deliberate choice per launch.
- **Per-id mounts** over mounting the whole store: limits exposure to the workspace's projects.
- **Scan with `grep`** in one pass over the workspace, no XML or C# parser. Three kinds of candidate (see the spec): `<UserSecretsId>` elements, ids written as literals next to `AddUserSecrets` or a `...UserSecretsId` constant, and any GUID-shaped string in source and project files. The GUID rule exists because an app can load a second secrets set by an id that only appears as a constant (`AddUserSecrets(SiteUserSecretsId)`), where the call itself holds no literal.
- **The host store is the filter.** A candidate only matters if `~/.microsoft/usersecrets/<candidate>` exists, so a stray GUID in source (a test fixture, an Azure resource id) mounts nothing. That keeps the mount limited to secrets the workspace actually names.
- **Id validation** against `^[A-Za-z0-9._-]+$` and rejecting `.` and `..`, so a malicious project file cannot cause an arbitrary host path to be mounted.
- **Standing rule in `CLAUDE.md`**, using the same begin/end marker approach as the port plan in `entrypoint.sh`, driven by `CLAUDE_YOLO_SECRETS`. Chosen because agents generally follow it, and the port block already shows the stripping logic.
- **One deny rule in `settings.json`**, `Read(//home/node/.microsoft/usersecrets/**)` (a leading `//` means an absolute path), edited with `jq` like the other settings the entrypoint manages. Per Claude Code's permissions documentation, Grep and Glob take no path rules of their own and a `Grep(...)` or `Glob(...)` rule never matches, but Read rules are applied to them best-effort, and to file commands Claude Code recognises in the shell. The rule is added or removed to match the variable each start, so a volume reused without `--secrets` does not keep it.
- **Read-only** (`:ro`) so the container cannot alter host secrets.

## Risks / Trade-offs

- Both guardrails are soft. A shell command (`cat`, `grep`, a script) can still read the files, and deny rules cannot reliably cover every shell form.
- The documentation does not say whether deny rules are enforced when Claude Code runs with `--dangerously-skip-permissions`. This is checked in a task; if they are not enforced, the rules stay in as harmless and the README says only the rule in `CLAUDE.md` applies.

- Secrets are readable by the agent and could be sent anywhere the container can reach; the flag, help text and README say so.
- The scan finds ids only in the file types listed. An id built at run time, read from configuration, or kept only in a file type not scanned (for example `.md` or `.json`) is missed; starting with a wider root does not help that case. An explicit `--secrets-id` option would cover it and is not part of this change.
- A GUID that happens to name a folder in the host store is mounted even if the code does not load it as user secrets. The workspace is the boundary and the folder must exist, so the exposure stays within secrets the user keeps for those same projects.
- Ids found in a nested project the user did not mean to expose are still mounted; the workspace is the boundary. Mounting the whole store was considered for the root-folder case and rejected: the scan reaches every project under the root while still leaving out secrets for projects outside it.
