{ pkgs }:
let
  # 0 = least warm, 100 = warmest.
  temperature = 100;

  applyNightShiftScript = pkgs.replaceVars ./apply-night-shift.sh {
    nightlightBin = "${pkgs.nightlight}/bin/nightlight";
    inherit temperature;
  };
in
{
  # Night Shift state lives in the per-user CoreBrightness session and is not
  # exposed through any plist `system.defaults` can write, so the only way to
  # express "on by default" is to talk to that session on login.
  #
  # RunAtLoad without a StartInterval deliberately makes this a default rather
  # than an enforcement: a manual toggle sticks until the next login.
  launchd.agents.night-shift = pkgs.lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${applyNightShiftScript}"
      ];
      RunAtLoad = true;
      StandardOutPath = "/tmp/night-shift.log";
      StandardErrorPath = "/tmp/night-shift.error.log";
    };
  };
}
