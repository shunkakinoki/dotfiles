function _corc_function --description "Run Codex remote-control with a stable binary"
  # Resolve the symlink to the real inode before starting.
  # When bun replaces the file (creates a new inode), the running node process
  # keeps its reference to the old inode and is unaffected.
  # Usage: corc [<codex remote-control args...>]

  set -l codex_real (realpath (which codex))
  $codex_real remote-control $argv
end
