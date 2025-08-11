{ pkgs, lib }:
with lib;
let
  ollamaBroken = (pkgs.ollama.meta.broken or false);
in
mkIf (!ollamaBroken) {
  launchd.agents.ollama = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.ollama}/bin/ollama"
        "serve"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables.OLLAMA_HOST = "0.0.0.0";
    };
  };
}
