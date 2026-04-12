{
  config,
  lib,
  pkgs,
  ...
}:
{
  # k3s config file stored in home directory
  home.file.".config/k3s/config.yaml" = lib.mkIf pkgs.stdenv.isLinux {
    source = ./config.yaml;
    force = true;
  };

  # Activation script to sync config to /etc/rancher/k3s/
  home.activation.k3s-config = lib.mkIf pkgs.stdenv.isLinux (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./activate.sh}
    ''
  );
}
