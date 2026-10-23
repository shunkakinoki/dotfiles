# Deployment freshness

The three-hour updater requires a clean `main` checkout that can fast-forward to
`origin/main`. A feature branch, tracked edits, or unpublished/divergent commits
produce a nonzero exit and remain intact. The updater never resets the checkout
or resolves development work automatically.

The updater installs its selected revision with `make install`, then syncs
dotagents. Only successful completion of both steps, with the selected HEAD still
present, advances `~/.local/state/dotfiles-updater/installed-commit` (or the same
path under XDG_STATE_HOME). Failed installs and syncs are attempted on a later run.
The marker records installation completion; it does not certify live service health.

When the updater reports a blocked checkout, preserve the branch, tracked edits,
and untracked files in their owning worktree or backup before restoring a clean
deployment checkout. Do not reset or clean somebody else's work. Run deployment
again after resolving the ownership issue, and verify the marker and services.

On Linux, inspect the user service's `Result` and `ExecMainStatus`, not just the
timer's active state. On macOS, inspect only the launch agent's state and exit-code
fields; avoid dumping inherited environment values. CLIProxy image refresh remains
best-effort and logs its own failures separately from installation freshness.
