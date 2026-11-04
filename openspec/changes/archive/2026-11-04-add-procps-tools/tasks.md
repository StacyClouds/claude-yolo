## 1. Red: failing test

- [x] 1.1 Add a check to the test suite that the final-stage `apt-get install` in the Dockerfile lists `procps`; run it and confirm it fails

## 2. Green: implementation

- [x] 2.1 Add `procps` to the final-stage `apt-get install` line in the Dockerfile
- [x] 2.2 Run the test suite and confirm it passes

## 3. Verify

- [x] 3.1 Run `claude-yolo rebuild`, start a container and confirm `pkill --version` works
- [x] 3.2 Run `openspec validate add-procps-tools`
