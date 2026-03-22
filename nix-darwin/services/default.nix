{
  lib,
  isRunner,
  pkgs,
}:
let
  pmsetBatteryPolicyModule = import ./pmset-battery-policy { inherit lib isRunner pkgs; };
in
[
  pmsetBatteryPolicyModule
]
