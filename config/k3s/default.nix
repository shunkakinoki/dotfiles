{
  config,
  lib,
  pkgs,
  ...
}:
{
  # k3s config file stored in home directory
  home.file.".config/k3s/config.yaml" = lib.mkIf pkgs.stdenv.isLinux {
    source = config.lib.file.mkOutOfStoreSymlink ./config.yaml;
  };

  # Activation script to sync config to /etc/rancher/k3s/
  home.activation.k3s-config = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "$HOME/.config/k3s/config.yaml" ]; then
        $DRY_RUN_CMD sudo mkdir -p /etc/rancher/k3s
        $DRY_RUN_CMD sudo cp "$HOME/.config/k3s/config.yaml" /etc/rancher/k3s/config.yaml
      fi
    ''
  );
}
