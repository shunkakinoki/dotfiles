{ lib, ... }:
{
  # Use activation script instead of home.file symlink.
  # Keep only the tracked config.yml in dotfiles and leave runtime state untouched.
  home.activation.ompConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.omp/agent ~/.omp/agent/extensions
    $DRY_RUN_CMD cp -f ${./config.yml} ~/.omp/agent/config.yml
    $DRY_RUN_CMD chmod 644 ~/.omp/agent/config.yml
    $DRY_RUN_CMD ln -sfn "$HOME/dotfiles/node_modules/@oh-my-pi/swarm-extension" ~/.omp/agent/extensions/swarm-extension
  '';
}
