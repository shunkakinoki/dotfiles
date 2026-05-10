{
  config,
  lib,
  pkgs,
  ...
}:
let
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  kubeconfig = "${config.home.homeDirectory}/.kube/config-kyber";
in
{
  home.file.".config/k3s/config.yaml" = lib.mkIf isLinux {
    source = ./config.yaml;
    force = true;
  };

  home.file.".config/k3s/k3s.service" = lib.mkIf isLinux {
    source = pkgs.replaceVars ./k3s.service {
      inherit (pkgs) coreutils k3s;
    };
    force = true;
  };

  home.sessionVariables = lib.mkIf (isLinux || isDarwin) {
    KUBECONFIG = kubeconfig;
  };

  programs.bash.bashrcExtra = lib.mkIf (isLinux || isDarwin) ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.zsh.initContent = lib.mkIf (isLinux || isDarwin) ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.fish.interactiveShellInit = lib.mkIf (isLinux || isDarwin) ''
    set -gx KUBECONFIG "${kubeconfig}"
  '';

  home.activation.k3s-server = lib.mkIf isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}"
    ''
  );

  home.activation.k3s-client = lib.mkIf isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-client.sh}"
    ''
  );
}
