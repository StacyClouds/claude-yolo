## 1. Install real git and the push-blocking wrapper

- [ ] 1.1 Add `git` to the final image's `apt-get install` list in `Dockerfile` (alongside `ca-certificates curl bash tini python3 jq`), and verify `docker build` succeeds with `/usr/bin/git --version` working inside the built image
- [x] 1.2 Replace the `/usr/local/bin/git` stub in `Dockerfile` with a wrapper script (`git-wrapper.sh`, `COPY`'d in) that: scans arguments past recognized global git options (`-C`, `--git-dir=`, `-c`, etc.) for the first subcommand token, blocks with a non-zero exit and a clear stderr message when that token is `push` or `send-pack`, and otherwise `exec`s `/usr/bin/git "$@"` — verified directly by running `git-wrapper.sh` standalone (`sh -n` syntax check plus executing it with a stand-in `REAL_GIT`) since Docker isn't available in this environment. Also had to add `!git-wrapper.sh` to `.dockerignore` (which excludes everything except `entrypoint.sh` by default) - without it the `COPY` failed the build with "not found" since the file was excluded from the build context
- [x] 1.3 Verify the wrapper blocks push regardless of remote name: `git push origin <branch>`, `git push upstream <branch>` (after simulating `git remote add upstream <url>` by passing the name directly), and `git send-pack` are all blocked identically — verified via the standalone script run above
- [x] 1.4 Verify the wrapper does not block non-push commands: `git status`, `git branch`, `git commit`, `git log`, `git diff`, `git merge`, `git stash`, `git fetch`, and `git clone` (plus `-C`, `-c`, `--git-dir=`, `--work-tree=` global-option variants, and a branch literally named `push-feature-branch`) all delegate through untouched — verified via the standalone script run above

## 2. Make git usable against the mounted workspace with no manual setup

- [ ] 2.1 Add `git config --system --add safe.directory '*'` to `Dockerfile` (trusting every repository path, not just `/workspace` itself) and verify `git status` succeeds (no "detected dubious ownership" error) against repos at multiple locations under `/workspace` (root, nested, and sibling directories) whose files are owned by a UID different from the container's `node` user
- [ ] 2.2 Add a fallback `git config --system user.name`/`user.email` to `Dockerfile` and verify `git commit` succeeds inside the container against a repo with no `user.name`/`user.email` set in its own local config
- [ ] 2.3 Verify a repo-local `user.name`/`user.email` (set via `git config --local` inside the mounted repo) still takes precedence over the fallback
- [ ] 2.4 Verify multi-repo correctness: with two sibling repos and a nested repo under `/workspace`, running `git status`/`git commit` with the working directory inside each one operates only on that repository (unmodified git repo-discovery), never a sibling or parent repo

## 3. Update documentation

- [x] 3.1 Update `Dockerfile`'s own header comment (currently "No `git` binary in the final image ... Claude can read/edit files but cannot commit, push, rewrite history, or touch remotes") to describe the new restricted-git behavior
- [x] 3.2 Update `README.md`'s "Why this exists" bullet ("There is no `git` binary in the image ... Mounted repos' `.git` folders are inert data") and the "What this sandbox does not protect against" section (which currently says "git itself doesn't work *inside* the container") to match
- [x] 3.3 Re-read both updated docs together and confirm no remaining sentence still claims git is entirely absent or non-functional inside the sandbox

## 4. End-to-end verification

- [ ] 4.1 `claude-yolo rebuild` followed by a full workflow inside the container against a workspace containing multiple repos (e.g. one at the `/workspace` root and another in a subdirectory) — create a branch, edit a file, stage, commit, view `git log` in each — completes successfully and each repo's changes stay isolated to it
- [ ] 4.2 Attempting `git push` (to `origin` and to a manually added second remote) in that same session fails with the block message and no network push occurs
