# host-user-secrets Specification

## Purpose

Let apps run inside the sandbox container with the .NET user secrets they have on the host, while exposing only the secrets the mounted workspace refers to.

## Requirements

### Requirement: Secrets are shared only when requested
`claude-yolo` SHALL mount host user secrets only when `--secrets` is given. Without it, no user-secrets path appears in the `docker run` arguments.

#### Scenario: Option absent
- **WHEN** `claude-yolo` starts a container without `--secrets`
- **THEN** the `docker run` arguments contain no `usersecrets` mount

### Requirement: Only ids the workspace refers to are mounted
With `--secrets`, `claude-yolo` SHALL collect candidate ids from the files under the workspace, and for each candidate whose folder `$HOME/.microsoft/usersecrets/<id>` exists, add a mount of that folder to `/home/node/.microsoft/usersecrets/<id>` with the read-only flag. Candidates are:
- the value of every `<UserSecretsId>` element in `*.csproj`, `*.fsproj`, `*.vbproj`, `*.props` and `*.targets` files;
- the string literal in every `AddUserSecrets("<id>")` call, and in every assignment to a name ending in `UserSecretsId` (for example `private const string SiteUserSecretsId = "<id>";`), in `*.cs`, `*.fs` and `*.vb` files;
- every GUID-shaped string in `*.cs`, `*.fs`, `*.vb`, `*.razor`, `*.cshtml`, `*.csproj`, `*.fsproj`, `*.vbproj`, `*.props` and `*.targets` files, which covers an id held in a constant and passed to `AddUserSecrets` by name.

Files under `.git`, `node_modules`, `bin` and `obj` SHALL be ignored. Folders in the host store that no candidate names SHALL NOT be mounted.

#### Scenario: Id declared in a project file
- **WHEN** the workspace has a project with `UserSecretsId` `abc-123` and the host has `~/.microsoft/usersecrets/abc-123` and `~/.microsoft/usersecrets/other`
- **THEN** the arguments contain `-v $HOME/.microsoft/usersecrets/abc-123:/home/node/.microsoft/usersecrets/abc-123:ro` and nothing for `other`

#### Scenario: Id held only in C# code
- **WHEN** a `.cs` file in the workspace has `private const string SiteUserSecretsId = "<guid>";` and calls `AddUserSecrets(SiteUserSecretsId)`, no project file declares `<guid>`, and the host has a folder named `<guid>`
- **THEN** that folder is mounted

#### Scenario: Literal id passed to AddUserSecrets
- **WHEN** a `.cs` file calls `AddUserSecrets("my-secrets")` and the host has a folder `my-secrets`
- **THEN** that folder is mounted

#### Scenario: Several projects under one root
- **WHEN** the workspace is a folder holding several projects, each referring to a different id that exists on the host
- **THEN** every one of those folders is mounted and no other

#### Scenario: Id mentioned only where it is not scanned
- **WHEN** a host folder's id appears only in a file under `bin`, `obj`, `node_modules` or `.git`, or only in a file type outside the list above
- **THEN** that folder is not mounted

#### Scenario: Id with no host folder
- **WHEN** the workspace refers to an id with no folder on the host
- **THEN** no mount is added for it and `claude-yolo` still starts

#### Scenario: Unsafe id
- **WHEN** a candidate contains characters other than letters, digits, `.`, `_`, `-`, or is `.` or `..` (for example `../x`)
- **THEN** it is ignored

### Requirement: The container is told when secrets are shared
With `--secrets`, `claude-yolo` SHALL pass `CLAUDE_YOLO_SECRETS=1` to the container. Without it, the variable SHALL NOT be passed.

#### Scenario: Variable passed only with the option
- **WHEN** `claude-yolo` starts a container with and without `--secrets`
- **THEN** the `docker run` arguments contain `CLAUDE_YOLO_SECRETS=1` only in the first case

### Requirement: A standing rule tells the agent not to touch the secrets
When `CLAUDE_YOLO_SECRETS=1` is set, the entrypoint SHALL add to the container's `CLAUDE.md`, between begin and end markers, a rule that the agent must never read, print, copy or send anything under `/home/node/.microsoft/usersecrets`, and that only the .NET runtime may use it. Repeated starts SHALL NOT duplicate the block. When the variable is not set, any such block SHALL be removed and the rest of the file kept.

#### Scenario: Rule added once
- **WHEN** the entrypoint runs twice with `CLAUDE_YOLO_SECRETS=1`
- **THEN** `CLAUDE.md` contains exactly one block, with the rule

#### Scenario: Rule removed when not requested
- **WHEN** the entrypoint runs without the variable and `CLAUDE.md` holds a stale block between the markers
- **THEN** the block is gone and the other content is unchanged

### Requirement: A deny rule covers the secrets folder
When `CLAUDE_YOLO_SECRETS=1` is set, the entrypoint SHALL add the permission deny rule `Read(//home/node/.microsoft/usersecrets/**)` to the container's Claude Code `settings.json`, keeping all other settings and rules. A separate rule for Grep or Glob SHALL NOT be added, because Claude Code ignores path rules for those tools and applies Read rules to them instead. When the variable is not set, the rule SHALL be removed and other deny rules kept. Repeated starts SHALL NOT duplicate the rule.

#### Scenario: Rule added
- **WHEN** the entrypoint runs with `CLAUDE_YOLO_SECRETS=1`
- **THEN** `permissions.deny` contains that Read rule exactly once, and an existing unrelated deny entry is still present

#### Scenario: Rule removed when not requested
- **WHEN** the entrypoint runs without the variable and `settings.json` holds the rule
- **THEN** it is removed and unrelated entries stay

### Requirement: The guardrails are described as soft
The README and the `CLAUDE.md` rule SHALL NOT claim that the agent is prevented from reading the secrets. The README SHALL state that the agent and the .NET runtime run as the same user, and that shell commands can still read the files.

#### Scenario: README wording
- **WHEN** the README section for `--secrets` is read
- **THEN** it says the guardrails are advisory and names shell access as not blocked

### Requirement: The option is documented
`--help` SHALL list `--secrets`, saying that it mounts the workspace's user secrets read-only and that they are readable by the agent.

#### Scenario: Help text
- **WHEN** `claude-yolo --help` runs
- **THEN** the output contains `--secrets`
