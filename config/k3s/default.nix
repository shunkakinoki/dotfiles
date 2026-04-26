{
  config,
  lib,
  pkgs,
  ...
}:
let
  kubeconfig = "${config.home.homeDirectory}/.kube/config";
in
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

  home.sessionVariables = lib.mkIf pkgs.stdenv.isLinux {
    KUBECONFIG = kubeconfig;
  };

  programs.bash.bashrcExtra = lib.mkIf pkgs.stdenv.isLinux ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.zsh.initExtra = lib.mkIf pkgs.stdenv.isLinux ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.fish.interactiveShellInit = lib.mkIf pkgs.stdenv.isLinux ''
    set -gx KUBECONFIG "${kubeconfig}"
  '';

  home.activation.k3s-config = lib.mkIf pkgs.stdenv.isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}"
    ''
  );
}
