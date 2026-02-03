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
      if [ -f "$HOME/.config/k3s/config.yaml" ]; then
        # Find sudo (NixOS uses /run/wrappers/bin/sudo)
        SUDO_CMD=""
        if command -v sudo >/dev/null 2>&1; then
          SUDO_CMD="sudo"
        elif [ -x /run/wrappers/bin/sudo ]; then
          SUDO_CMD="/run/wrappers/bin/sudo"
        elif [ -x /usr/bin/sudo ]; then
          SUDO_CMD="/usr/bin/sudo"
        fi

        if [ -n "$SUDO_CMD" ]; then
          $DRY_RUN_CMD $SUDO_CMD mkdir -p /etc/rancher/k3s
          $DRY_RUN_CMD $SUDO_CMD cp "$HOME/.config/k3s/config.yaml" /etc/rancher/k3s/config.yaml
        else
          echo "Warning: sudo not found, skipping k3s config installation" >&2
        fi
      fi
    ''
  );
}
