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
    ip6tables = "${pkgs.iptables}/bin/ip6tables";
    ip = "${pkgs.iproute2}/bin/ip";
  };
in
lib.mkIf host.isKyber {
  home.activation.setupFirewall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${activateScript}"
  '';
}
