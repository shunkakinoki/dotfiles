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
      # Background QoS stretches each CoreAudio device enumeration from ~0.1s
      # to minutes, so the 2s poll would take minutes to react.
      ProcessType = "Standard";
      StandardOutPath = "/tmp/audio-priority.log";
      StandardErrorPath = "/tmp/audio-priority.error.log";
    };
  };
}
