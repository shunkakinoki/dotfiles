{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isGalactica isK3sServer k3s;
  clusterName = if isK3sServer then k3s.clusterName else "kyber";
  kubeconfig =
    if isGalactica then
      "${config.home.homeDirectory}/.kube/config-kyber"
    else
      "${config.home.homeDirectory}/.kube/config";
  kubeletConfigName = "10-${clusterName}.conf";
  k3sConfigFormat = pkgs.formats.yaml { };
  k3sConfig = k3sConfigFormat.generate "k3s-${clusterName}-config.yaml" {
    disable = [
      "traefik"
      "metrics-server"
    ];
    kubelet-arg = [ "max-pods=${toString k3s.maxPods}" ];
    node-label = [
      "infra.shunkakinoki.software/cluster=${clusterName}"
      "infra.shunkakinoki.software/workload-profile=${k3s.workloadProfile}"
    ];
    tls-san = k3s.tlsSans;
  };
  # Authorize galactica on k3s servers so the client activation can scp the
  # kubeconfig over Tailscale.
  galacticaAuthorizedKey = (import ../../named-hosts/pubkeys.nix).galactica;
  serverActivateScript = pkgs.replaceVars ./activate.sh {
    inherit galacticaAuthorizedKey kubeletConfigName;
    tailscaleDns = if isK3sServer then k3s.tailscaleDns else "kyber.tail950b36.ts.net";
  };
in
{
  home.file.".config/k3s/config.yaml" = lib.mkIf isK3sServer {
    source = k3sConfig;
    force = true;
  };

  home.file.".config/k3s/kubelet.conf.d/${kubeletConfigName}" = lib.mkIf isK3sServer {
    source = ./kubelet.conf;
    force = true;
  };

  home.file.".config/k3s/k3s.service" = lib.mkIf isK3sServer {
    source = pkgs.replaceVars ./k3s.service {
      inherit (pkgs) coreutils k3s;
    };
    force = true;
  };

  home.sessionVariables = lib.mkIf (isK3sServer || isGalactica) {
    KUBECONFIG = kubeconfig;
  };

  programs.bash.bashrcExtra = lib.mkIf (isK3sServer || isGalactica) ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.zsh.initContent = lib.mkIf (isK3sServer || isGalactica) ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.fish.interactiveShellInit = lib.mkIf (isK3sServer || isGalactica) ''
    set -gx KUBECONFIG "${kubeconfig}"
  '';

  home.activation.k3s-server = lib.mkIf isK3sServer (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${serverActivateScript}"
    ''
  );

  home.activation.k3s-client = lib.mkIf isGalactica (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-client.sh}"
    ''
  );
}
