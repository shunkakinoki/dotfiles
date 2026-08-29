{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host)
    isGalactica
    isK3sServer
    isKyber
    k3s
    ;
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
    resolv-conf = "/etc/rancher/k3s/resolv.conf";
    tls-san = k3s.tlsSans;
  };
  # Authorize galactica on k3s servers so the client activation can scp the
  # kubeconfig over Tailscale.
  galacticaAuthorizedKey = (import ../../named-hosts/pubkeys.nix).galactica;
  serverActivateScript = pkgs.replaceVars ./activate.sh {
    inherit galacticaAuthorizedKey kubeletConfigName;
    tailscaleDns = if isK3sServer then k3s.tailscaleDns else "kyber.tail950b36.ts.net";
  };
  alertScript = pkgs.writeShellApplication {
    name = "kyber-host-alert";
    runtimeInputs = [ pkgs.util-linux ];
    text = builtins.readFile ./kyber-host-alert.sh;
  };
  healthCheckScript = pkgs.writeShellApplication {
    name = "kyber-host-health";
    runtimeInputs = [
      alertScript
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.k3s
      pkgs.procps
      pkgs.smartmontools
      pkgs.sysstat
      pkgs.systemd
      pkgs.util-linux
    ];
    text = builtins.readFile ./kyber-host-health.sh;
  };
  healthCheckService = pkgs.replaceVars ./kyber-host-health.service {
    inherit healthCheckScript;
  };
  smartdConfig = pkgs.replaceVars ./kyber-smartd.conf {
    inherit alertScript;
  };
  smartdService = pkgs.replaceVars ./kyber-smartd.service {
    smartd = "${pkgs.smartmontools}/bin/smartd";
    inherit smartdConfig;
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

  home.file.".config/k3s/resolv.conf" = lib.mkIf isK3sServer {
    source = ./resolv.conf;
    force = true;
  };

  home.file.".config/k3s/k3s.service" = lib.mkIf isK3sServer {
    source = pkgs.replaceVars ./k3s.service {
      inherit (pkgs) coreutils k3s;
    };
    force = true;
  };

  home.file.".config/k3s/var-lib-rancher-k3s-agent-containerd.mount" = lib.mkIf isKyber {
    source = ./containerd.mount;
    force = true;
  };

  home.file.".config/k3s/journald.conf.d/10-kyber-limits.conf" = lib.mkIf isKyber {
    source = ./journald.conf;
    force = true;
  };

  home.file.".config/k3s/tmp.mount" = lib.mkIf isKyber {
    source = ./kyber-tmp.mount;
    force = true;
  };

  home.file.".config/k3s/kyber-host-health.service" = lib.mkIf isKyber {
    source = healthCheckService;
    force = true;
  };

  home.file.".config/k3s/kyber-host-health.timer" = lib.mkIf isKyber {
    source = ./kyber-host-health.timer;
    force = true;
  };

  home.file.".config/k3s/kyber-smartd.service" = lib.mkIf isKyber {
    source = smartdService;
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
    config.lib.dag.entryAfter [ "setupK3s" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${serverActivateScript}"
    ''
  );

  home.activation.k3s-client = lib.mkIf isGalactica (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-client.sh}"
    ''
  );
}
