{
  lib,
  isRunner,
  pkgs,
}:
let
  highBatteryThreshold = 30;
  highBatterySleepMinutes = 300;
  lowBatterySleepMinutes = 30;
  pmsetBatteryPolicyScript = builtins.readFile (
    pkgs.replaceVars ./power-policy.sh {
      awkBin = "/usr/bin/awk";
      inherit highBatteryThreshold highBatterySleepMinutes lowBatterySleepMinutes;
      pmsetBin = "/usr/bin/pmset";
    }
  );
in
lib.mkIf (!isRunner) {
  system.activationScripts.pmsetBatteryPolicy.text = lib.mkAfter pmsetBatteryPolicyScript;

  launchd.daemons."com.shunkakinoki.pmset-battery-policy" = {
    script = pmsetBatteryPolicyScript;
    serviceConfig = {
      RunAtLoad = true;
      StartInterval = 86400;
    };
  };
}
