{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  enforceScript = pkgs.replaceVars ./enforce.sh {
    switchAudioBin = "${pkgs.switchaudio-osx}/bin/SwitchAudioSource";
    outputDevice = "EarPods";
    inputDevice = "EarPods Microphone";
  };
in
lib.mkIf (inputs.host.isGalactica && pkgs.stdenv.hostPlatform.isDarwin) {
  launchd.agents.audio-priority = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "${enforceScript}"
      ];
      EnvironmentVariables.PATH = "/usr/bin:/bin";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      ProcessType = "Background";
      StandardOutPath = "/tmp/audio-priority.log";
      StandardErrorPath = "/tmp/audio-priority.error.log";
    };
  };
}
