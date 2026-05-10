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
  # Single source of truth for how the kyber k3s API is reached from
  # other tailnet members. Both server-side and client-side activate
  # scripts rewrite the kubeconfig server URL to this value, so kubectl
  # works the same on every host.
  kyberHost = "kyber.tail950b36.ts.net";
  kyberUser = "ubuntu";
  kyberApiUrl = "https://${kyberHost}:6443";
  # Authorize galactica on kyber so the client activation can scp the
  # kubeconfig over Tailscale.
  galacticaAuthorizedKey = (import ../../named-hosts/pubkeys.nix).galactica;
  serverActivateScript = pkgs.replaceVars ./activate.sh {
    inherit galacticaAuthorizedKey kyberApiUrl;
  };
  clientActivateScript = pkgs.replaceVars ./activate-client.sh {
    inherit kyberApiUrl kyberHost kyberUser;
  };
in
{
  home.file.".config/k3s/config.yaml" = lib.mkIf isKyber {
    source = ./config.yaml;
    force = true;
  };

  home.file.".config/k3s/k3s.service" = lib.mkIf isKyber {
    source = pkgs.replaceVars ./k3s.service {
      inherit (pkgs) coreutils k3s;
    };
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
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${serverActivateScript}"
    ''
  );

  home.activation.k3s-client = lib.mkIf isGalactica (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${clientActivateScript}"
    ''
  );
}
