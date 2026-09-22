#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'dotfiles-updater/update.sh'
SCRIPT="$PWD/home-manager/services/dotfiles-updater/update.sh"
MODULE="$PWD/home-manager/services/dotfiles-updater/default.nix"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'changes to ~/dotfiles directory'
When run bash -c "grep 'cd ~/dotfiles' '$SCRIPT'"
The output should include 'cd ~/dotfiles'
End
End

Describe 'service host identity'
It 'passes the canonical named host to automatic updates'
When run bash -c "grep 'HOST=\${canonicalHost}' '$MODULE'"
The output should include 'HOST=${canonicalHost}'
End

It 'derives the canonical host from named-host flags'
When run bash -c "grep -E 'inputs.host.is(Kyber|Matic)' '$MODULE'"
The output should include 'inputs.host.isKyber'
The output should include 'inputs.host.isMatic'
End
End

Describe 'branch detection'
It 'checks current branch name'
When run bash -c "grep 'rev-parse --abbrev-ref HEAD' '$SCRIPT'"
The output should include 'rev-parse --abbrev-ref HEAD'
End

It 'skips update when not on main'
When run bash -c "grep 'not main' '$SCRIPT'"
The output should include 'not main'
End

It 'exits cleanly when skipping'
When run bash -c "grep -A 1 'not main' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'git operations'
It 'fetches from origin main'
When run bash -c "grep 'git fetch origin main' '$SCRIPT'"
The output should include 'git fetch origin main'
End

It 'resets to origin/main'
When run bash -c "grep 'git reset --hard origin/main' '$SCRIPT'"
The output should include 'git reset --hard origin/main'
End
End

Describe 'change detection'
It 'stores current commit before fetching'
When run bash -c "grep 'CURRENT_COMMIT=\$(git rev-parse HEAD)' '$SCRIPT'"
# shellcheck disable=SC2016
The output should include 'CURRENT_COMMIT=$(git rev-parse HEAD)'
End

It 'gets remote commit after fetching'
When run bash -c "grep 'REMOTE_COMMIT=\$(git rev-parse origin/main)' '$SCRIPT'"
# shellcheck disable=SC2016
The output should include 'REMOTE_COMMIT=$(git rev-parse origin/main)'
End

It 'compares the last installed commit to detect changes'
When run bash -c "grep 'INSTALLED_COMMIT.*=.*REMOTE_COMMIT' '$SCRIPT'"
The output should include 'INSTALLED_COMMIT'
The output should include 'REMOTE_COMMIT'
End

It 'skips build when no changes detected'
When run bash -c "grep 'No changes detected' '$SCRIPT'"
The output should include 'No changes detected'
End

It 'logs when changes are detected'
When run bash -c "grep 'Changes detected' '$SCRIPT'"
The output should include 'Changes detected'
End
End

Describe 'installation'
It 'runs install.sh after update'
When run bash -c "grep './install.sh' '$SCRIPT'"
The output should include './install.sh'
End
End

Describe 'service PATH'
It 'provides grep to install.sh'
When run bash -c "grep 'pkgs.gnugrep' '$MODULE'"
The output should include 'pkgs.gnugrep'
End
End

Describe 'failed install retry'
setup() {
  WORK=$(mktemp -d)
  export HOME="$WORK/home"
  export XDG_STATE_HOME="$WORK/state"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  mkdir -p "$HOME" "$WORK/src"
  git -C "$WORK/src" init -q -b main
  cat >"$WORK/src/install.sh" <<'INSTALL'
#!/usr/bin/env bash
[ -f "$HOME/install-fails" ] && exit 1
touch "$HOME/installed"
INSTALL
  chmod +x "$WORK/src/install.sh"
  git -C "$WORK/src" add install.sh
  git -C "$WORK/src" commit -q -m base
  git clone -q "$WORK/src" "$HOME/dotfiles" 2>/dev/null
  git -C "$WORK/src" commit -q --allow-empty -m update
}

cleanup() {
  rm -rf "$WORK"
}

Before 'setup'
After 'cleanup'

It 'retries the install on the next run after install.sh fails'
touch "$HOME/install-fails"
When run bash -c "bash '$SCRIPT' >/dev/null 2>&1; rm -f '$HOME/install-fails'; bash '$SCRIPT' 2>/dev/null && test -f '$HOME/installed' && echo retried"
The output should include 'Changes detected'
The output should include 'retried'
End

It 'skips the install once the fetched commit was installed'
When run bash -c "bash '$SCRIPT' >/dev/null 2>&1 && bash '$SCRIPT' 2>/dev/null"
The output should include 'No changes detected'
End

# The dotenv is placed out of band, so it can land after the switch that needed
# it. Commit equality alone would skip activation forever and strand the host on
# whatever it rendered without the file.
It 'reinstalls when the dotenv lands after the commit was installed'
When run bash -c "bash '$SCRIPT' >/dev/null 2>&1 && rm -f '$HOME/installed' && printf 'K=v\n' >'$HOME/dotfiles/.env' && bash '$SCRIPT' 2>/dev/null && test -f '$HOME/installed' && echo reinstalled"
The output should include 'Dotenv changed'
The output should include 'reinstalled'
End

It 'reinstalls when the dotenv contents change'
When run bash -c "printf 'K=v\n' >'$HOME/dotfiles/.env' && bash '$SCRIPT' >/dev/null 2>&1 && rm -f '$HOME/installed' && printf 'K=w\n' >'$HOME/dotfiles/.env' && bash '$SCRIPT' 2>/dev/null && test -f '$HOME/installed' && echo reinstalled"
The output should include 'reinstalled'
End

It 'skips when neither the commit nor the dotenv changed'
When run bash -c "printf 'K=v\n' >'$HOME/dotfiles/.env' && bash '$SCRIPT' >/dev/null 2>&1 && bash '$SCRIPT' 2>/dev/null"
The output should include 'No changes detected'
End

It 'records a digest of the dotenv rather than its contents'
When run bash -c "printf 'SECRET=topsecretvalue\n' >'$HOME/dotfiles/.env' && bash '$SCRIPT' >/dev/null 2>&1 && ! grep -q topsecretvalue \"\$XDG_STATE_HOME/dotfiles-updater/installed-dotenv\" && echo redacted"
The output should include 'redacted'
End
End

End
