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
    awk = "${pkgs.gawk}/bin/awk";
  };
in
lib.mkIf host.isKyber {
  home.activation.setupFirewall = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${activateScript}"
  '';
}
