## 1. Red: failing tests

- [x] 1.1 Add a test that without `--secrets` the logged `docker run` arguments contain no `usersecrets` and no `CLAUDE_YOLO_SECRETS`
- [x] 1.2 Add a test with a stub workspace and a stub `$HOME`: matching id is mounted read-only to the same id path, a non-matching host folder is not, and `CLAUDE_YOLO_SECRETS=1` is passed
- [x] 1.3 Add tests: missing host folder adds no mount and still starts; unsafe ids (`../x`, `.`, `..`) are ignored; ids in `Directory.Build.props` are found
- [x] 1.3a Add tests for ids named only in code: a GUID constant passed to `AddUserSecrets` by name, a literal `AddUserSecrets("name")`, several projects under one root, and ids found only under `bin`, `obj`, `node_modules` or in a `.md` file not mounted; run and confirm they fail
- [x] 1.4 Add a test that `--help` lists `--secrets`
- [x] 1.5 Add entrypoint tests for the `CLAUDE.md` block: added once with the variable, not duplicated on a second run, stripped without the variable while other content is kept
- [x] 1.6 Add entrypoint tests for the `settings.json` deny rule: the Read rule added once with the variable, no Grep or Glob entries, unrelated deny entries kept, rule removed without the variable, no duplicates on rerun
- [x] 1.7 Run the suites and confirm each new test fails

## 2. Green: implementation

- [x] 2.1 Parse `--secrets` in `claude-yolo` alongside `--ports`, before the subcommand
- [x] 2.2 Scan the workspace for ids, validate them, and build the `-v ...:ro` arguments and `-e CLAUDE_YOLO_SECRETS=1`
- [x] 2.2a Extend the scan to ids in code (literal `AddUserSecrets`, `...UserSecretsId` constants, GUID-shaped strings) and to `*.fsproj`, `*.vbproj`, `*.targets`; skip `.git`, `node_modules`, `bin`, `obj`
- [x] 2.3 Add them to `run_container`; update `print_help`
- [x] 2.4 Add the `CLAUDE.md` block handling to `entrypoint.sh`
- [x] 2.5 Add the `settings.json` deny rule handling to `entrypoint.sh`
- [x] 2.6 Run the suites and confirm they pass

## 3. Verify and document

- [x] 3.1 Update the README, including that the guardrails are soft and the shell is not blocked
- [x] 3.2 Start a container with `--secrets` on a real project, including one that loads a second set by an id held in a constant, and confirm the app sees its secrets and cannot write them
- [x] 3.3 In that container, run Claude Code the way `claude-yolo` does and check whether the deny rules stop the Read tool on a secrets file; record the result in the README
- [x] 3.4 Run `openspec validate share-host-user-secrets`
