{
  lib,
  isRunner,
  pkgs,
}:
let
  nixGcModule = import ./nix-gc { inherit lib isRunner; };
  pmsetBatteryPolicyModule = import ./pmset-battery-policy { inherit lib isRunner pkgs; };
  sysctlPtmxModule = import ./sysctl-ptmx { inherit lib isRunner; };
in
[
  nixGcModule
  pmsetBatteryPolicyModule
  sysctlPtmxModule
]
