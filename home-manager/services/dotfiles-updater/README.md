# Deployment freshness

The three-hour updater requires a clean `main` checkout that can fast-forward to
`origin/main`. A feature branch, tracked edits, or unpublished/divergent commits
produce a nonzero exit and remain intact. The updater never resets the checkout
or resolves development work automatically. The one exception is
`generated/hooks/moshi`: moshi-hook output that hosts never edit by hand. When
it is the only changed path, the updater restores it to HEAD and continues.

The updater installs its selected revision with `make install`, then syncs
dotagents. Only successful completion of both steps, with the selected HEAD still
present, advances `~/.local/state/dotfiles-updater/installed-commit` (or the same
path under XDG_STATE_HOME). Failed installs and syncs are attempted on a later run.
The marker records installation completion; it does not certify live service health.

On automated Kamino updates, a local Nix build starts only with at least 64 GiB
free on the root filesystem. This reserve uses the 42 GiB needed to preserve
one executor lane and adds margin based on roughly 20 GB of K4 Nix-store growth
observed during an updater run. That observed growth does not bound every
future build. Between 42 and 64 GiB, the updater can apply an activation
closure already present in the local Nix store while disabling local Nix
builds for that install. If the closure is missing, the updater leaves the
installed marker unchanged and retries on the next timer. A trusted Nix builder
can build this exact flake output at the target commit and copy its closure into
the host store with `nix copy`; the updater verifies it with offline
`nix path-info --recursive`. Otherwise, free root space or increase host capacity
above 64 GiB so the timer can build locally. At less than 42 GiB free,
automated updates defer without applying changes.

When the updater reports a blocked checkout, preserve the branch, tracked edits,
and untracked files in their owning worktree or backup before restoring a clean
deployment checkout. Do not reset or clean somebody else's work. Run deployment
again after resolving the ownership issue, and verify the marker and services.

On Linux, inspect the user service's `Result` and `ExecMainStatus`, not just the
timer's active state. On macOS, inspect only the launch agent's state and exit-code
fields; avoid dumping inherited environment values. CLIProxy image refresh remains
best-effort and logs its own failures separately from installation freshness.
