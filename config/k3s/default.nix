{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.k3s.serviceFile = lib.mkOption {
    type = lib.types.package;
    default = pkgs.writeText "k3s.service" (
      builtins.readFile (
        pkgs.replaceVars ./k3s.service {
          inherit (pkgs) coreutils;
          k3s = pkgs.k3s;
        }
      )
    );
    readOnly = true;
    description = "Rendered k3s systemd service file";
  };

  config = {
    # k3s config file stored in home directory
    home.file.".config/k3s/config.yaml" = lib.mkIf pkgs.stdenv.isLinux {
      source = ./config.yaml;
      force = true;
    };

    # Activation script to sync config to /etc/rancher/k3s/
    home.activation.k3s-config = lib.mkIf pkgs.stdenv.isLinux (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}"
      ''
    );
  };
}
