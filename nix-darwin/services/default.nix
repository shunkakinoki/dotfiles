{
  lib,
  isRunner,
  pkgs,
}:
let
  ironProxyModule = import ./iron-proxy { inherit lib isRunner pkgs; };
  nixGcModule = import ./nix-gc { inherit lib isRunner; };
  pmsetBatteryPolicyModule = import ./pmset-battery-policy { inherit lib isRunner pkgs; };
  sysctlPtmxModule = import ./sysctl-ptmx { inherit lib isRunner; };
in
[
  ironProxyModule
  nixGcModule
  pmsetBatteryPolicyModule
  sysctlPtmxModule
]
