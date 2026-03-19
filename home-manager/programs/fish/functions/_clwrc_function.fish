function _clwrc_function --description "Run Claude Code remote-control with a stable binary in workspace git worktree"
  # Resolve the symlink to the real inode before starting.
  # When bun replaces the file (creates a new inode), the running node process
  # keeps its reference to the old inode and is unaffected.
  # Usage: clwrc [<claude remote-control args...>]

  set -l claude_real (realpath (which claude))
  $claude_real remote-control --spawn worktree --permission-mode bypassPermissions $argv
end
