{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  activateScript = pkgs.replaceVars ./activate.sh {
    iptables = "${pkgs.iptables}/bin/iptables";
  };
in
lib.mkIf host.isKyber {
  home.activation.setupFirewall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${activateScript}"
  '';
}
