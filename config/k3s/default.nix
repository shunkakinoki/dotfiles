{
  lib,
  pkgs,
  ...
}:
{
  home.file.".config/k3s/config.yaml" = lib.mkIf pkgs.stdenv.isLinux {
    source = ./config.yaml;
    force = true;
  };

  home.file.".config/k3s/k3s.service" = lib.mkIf pkgs.stdenv.isLinux {
    source = pkgs.replaceVars ./k3s.service {
      inherit (pkgs) coreutils;
      k3s = pkgs.k3s;
    };
    force = true;
  };

  home.activation.k3s-config = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}"
    ''
  );
}
