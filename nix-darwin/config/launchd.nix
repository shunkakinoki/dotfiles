{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.ollamaAgent;
in
{
  options.services.ollamaAgent.enable = mkEnableOption "Launchd agent for Ollama";

  config = mkIf cfg.enable {
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
  };
}
