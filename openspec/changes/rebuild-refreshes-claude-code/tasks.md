## 1. Rebuild flags (red, then green)

- [x] 1.1 Add failing tests to `test/claude-yolo.test.sh`: `rebuild` logs `--pull` and a `CLAUDE_CODE_CACHE_BUST=` build arg, two rebuilds a second apart log different values, and the automatic build on `run` with a missing image logs neither; verify they fail for the right reason
- [x] 1.2 Make `build_image` accept extra arguments and have `rebuild` pass `--pull --build-arg CLAUDE_CODE_CACHE_BUST=<unix time>`; verify the tests from 1.1 pass and the existing tests still pass

## 2. Image build

- [x] 2.1 Declare `ARG CLAUDE_CODE_CACHE_BUST=` directly before the `npm install -g` step in the `Dockerfile` and correct the comment above it; verify hadolint passes

## 3. Documentation

- [x] 3.1 Update `README.md` and the `rebuild` line in `claude-yolo --help` to say `rebuild` refreshes Claude Code and the base image; verify against the spec

## 4. Verification

- [ ] 4.1 On a machine with Docker, run `claude-yolo rebuild` twice and confirm the npm install step reruns while the apt layers stay cached
