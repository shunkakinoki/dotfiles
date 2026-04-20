{
  lib,
  isRunner,
  pkgs,
}:
let
  nixGcModule = import ./nix-gc { inherit lib isRunner; };
  pmsetBatteryPolicyModule = import ./pmset-battery-policy { inherit lib isRunner pkgs; };
in
[
  nixGcModule
  pmsetBatteryPolicyModule
]
