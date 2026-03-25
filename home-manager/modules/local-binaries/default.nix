{ config, pkgs, ... }:
{
  # Create ~/.local/bin directory
  home.file.".local/bin/.keep".text = "";

  # Symlink local binaries during activation
  home.activation.symlinkLocalBinaries = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./sync-local-binaries.sh}
  '';
}
