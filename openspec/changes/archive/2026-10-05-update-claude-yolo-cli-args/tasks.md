## 1. Test harness (Red)

- [x] 1.1 Create `test/claude-yolo.test.sh`: a POSIX `sh` test runner with a fake `docker` stub it puts on `PATH` (the stub appends each invocation's arguments to a log file instead of touching real Docker), plus a small assertion helper (expect exit code, expect stub log contents, expect stderr contains text) and a results summary
- [x] 1.2 Add failing test cases to it covering: `--help`/`-h` exit 0 with no docker invocation and usage text printed; a bare positional existing-directory argument mounts as `/workspace` (assert the stub's `run` invocation's `-v` argument); `--workspace <path>` still works unchanged; a nonexistent bare positional path exits non-zero with an error before any docker call; `rebuild`/`run`/`yolo`/`nuke` keywords are always treated as subcommands even if a same-named directory exists; `run -- "text"` forwards `"text"` to the stub's `claude` invocation; `run "text"` (no `--`) exits non-zero with an error mentioning `--` and makes no docker call; `-- --model opus -p "query"` forwards those flags verbatim
- [x] 1.3 Run `sh test/claude-yolo.test.sh` and verify every new case fails (the script hasn't changed yet) — confirms the tests actually exercise the new behavior (31 cases exercised, 18 genuine failures against the unmodified script; also fixed a test-harness bug where `grep -qF` misparsed patterns starting with `-`)

## 2. Implementation (Green)

- [x] 2.1 Add `--help`/`-h` handling at the very top of the argument parsing in `claude-yolo`, printing a usage message (subcommands, workspace-override forms, the `--` convention, examples) and exiting 0 before any other parsing
- [x] 2.2 Change the `--workspace`/bare-positional parsing: keep the existing `--workspace <path>` branch as-is; add an `elif` branch that, when the first remaining argument is not `--help`/`-h`, not `--workspace`, and not one of `rebuild`/`nuke`/`run`/`yolo`, validates it as a directory (same error message style as the existing `--workspace` validation, extended to also mention `--` as the alternative) and sets `PROJECT_DIR` from it, then shifts
- [x] 2.3 After subcommand-mode resolution, in the `run` and `yolo` branches only, require the next remaining argument to be literal `--` (shift past it) when any arguments remain; otherwise exit with an error naming the unexpected argument and mentioning `--`. Leave `rebuild` and `nuke` untouched (including `nuke`'s own `--preserve-token` parsing)
- [x] 2.4 Update the script's top-of-file usage comment block to document the new grammar (bare positional workspace path, `--` separator, `--help`)
- [x] 2.5 Run `sh test/claude-yolo.test.sh` and verify every case now passes (31/31 passed)

## 3. Docs and lint (Green)

- [x] 3.1 Update `README.md`'s `claude-yolo` "Usage" and "Choosing the workspace folder" sections to show the bare-positional workspace form, the `--` separator, and `--help`
- [x] 3.2 Run ShellCheck against `claude-yolo` and the new `test/claude-yolo.test.sh` and verify no new warnings (clean, zero warnings)
- [x] 3.3 Manually ran `claude-yolo --help` (prints usage, exit 0), `claude-yolo .` (mounted `/workspace:/workspace`, i.e. the current directory, confirmed via a `docker` stub on `PATH`), and `claude-yolo -- "say hi"` (forwarded `say hi` to the `claude` invocation). This sandbox has no real Docker daemon (same limitation noted in `float-claude-code-version`), so the stub was used in place of a real build/run; a real `docker build`/`claude-yolo rebuild` against this change still needs to happen on a Docker-capable machine
