{ pkgs, ... }:
let
  setup = pkgs.replaceVars ./setup.sh {
    preseed = ./preseed.yaml;
    networkScript = ./network.sh;
    networkService = ./kyber-incus-network.service;
  };
in
{
  xdg.configFile."crabbox/config.yaml".source = ./crabbox.yaml;

  # Ubuntu owns the privileged daemon and its security updates. A normal
  # Home Manager switch installs the setup command without changing the host.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "kyber-incus-setup";
      runtimeInputs = [ pkgs.jq ];
      text = ''
        exec ${pkgs.bash}/bin/bash ${setup}
      '';
    })
  ];
}
