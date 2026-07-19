{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.host) isKyber isGalactica;
  kubeconfig = "${config.home.homeDirectory}/.kube/config-kyber";
  # Authorize galactica on kyber so the client activation can scp the
  # kubeconfig over Tailscale.
  galacticaAuthorizedKey = (import ../../named-hosts/pubkeys.nix).galactica;
  serverActivateScript = pkgs.replaceVars ./activate.sh {
    inherit galacticaAuthorizedKey;
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
  home.file.".config/k3s/config.yaml" = lib.mkIf isKyber {
    source = ./config.yaml;
    force = true;
  };

  home.file.".config/k3s/kubelet.conf.d/10-kyber.conf" = lib.mkIf isKyber {
    source = ./kubelet.conf;
    force = true;
  };

  home.file.".config/k3s/k3s.service" = lib.mkIf isKyber {
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

  home.sessionVariables = lib.mkIf (isKyber || isGalactica) {
    KUBECONFIG = kubeconfig;
  };

  programs.bash.bashrcExtra = lib.mkIf (isKyber || isGalactica) ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.zsh.initContent = lib.mkIf (isKyber || isGalactica) ''
    export KUBECONFIG="${kubeconfig}"
  '';

  programs.fish.interactiveShellInit = lib.mkIf (isKyber || isGalactica) ''
    set -gx KUBECONFIG "${kubeconfig}"
  '';

  home.activation.k3s-server = lib.mkIf isKyber (
    lib.hm.dag.entryAfter [ "setupK3s" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${serverActivateScript}"
    ''
  );

  home.activation.k3s-client = lib.mkIf isGalactica (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate-client.sh}"
    ''
  );
}
