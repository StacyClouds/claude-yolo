## Why

.NET apps read configuration from user secrets, stored on the host in `~/.microsoft/usersecrets/<UserSecretsId>/secrets.json`. The container has its own empty store, so apps run there without their secrets and fail. Mounting the host's whole store would hand every project's secrets to an agent running in YOLO mode (no permission prompts) with network access, so only the secrets the workspace actually uses should be shared.

## What Changes

- Add an opt-in `--secrets` option to `claude-yolo`.
- With it, `claude-yolo` collects candidate ids from the workspace: `<UserSecretsId>` elements in project and props files, ids passed to `AddUserSecrets("...")` or assigned to a `...UserSecretsId` constant in code, and any GUID-shaped string in source and project files (which catches an id held in a constant and passed by name). For each candidate whose folder exists on the host, it bind-mounts that folder read-only at the same place under `/home/node/.microsoft/usersecrets/`. Starting in a folder that holds many projects therefore shares the secrets of all of them, and nothing else.
- Ids that are not a plain identifier (letters, digits, `.`, `_`, `-`) are ignored.
- Without the option nothing is mounted.
- With the option, `claude-yolo` also sets `CLAUDE_YOLO_SECRETS=1` in the container. `entrypoint.sh` then adds two guardrails against the agent reading the secrets: a standing rule in the container's `CLAUDE.md`, and a permission deny rule in the container's Claude Code `settings.json`, `Read(//home/node/.microsoft/usersecrets/**)`, which Claude Code applies on a best-effort basis to its Grep and Glob tools and to file commands it recognises in the shell (such as `cat`). Both are removed on a start without the option.
- These guardrails are soft. The agent and the .NET runtime run as the same user, so no mechanism can let one read the secrets and stop the other.
- `--help` and the README describe the option, the read-only behaviour, and the exposure to the agent.

## Capabilities

### New Capabilities
- `host-user-secrets`: selected host .NET user secrets are available read-only in the container.

### Modified Capabilities

## Impact

- `claude-yolo`: option parsing, workspace scan, extra `-v` arguments, `CLAUDE_YOLO_SECRETS` environment variable.
- `entrypoint.sh`: marked `CLAUDE.md` block and `settings.json` deny rules, added or stripped on every start.
- `test/entrypoint.test.sh`: new cases.
- `test/claude-yolo.test.sh`: new cases.
- Host support: macOS and Linux path `~/.microsoft/usersecrets`; Windows hosts are not supported.
- Secrets are readable by anything running in the container, including the agent; that is why the option is opt-in. The guardrails reduce accidental reads but do not prevent deliberate ones (for example a shell command such as `cat`).
