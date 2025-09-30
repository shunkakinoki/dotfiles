{ pkgs }:
{
  launchd.agents.ollama = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.ollama}/bin/ollama"
        "serve"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables.OLLAMA_HOST = "0.0.0.0";
      StandardOutPath = "/tmp/ollama.log";
      StandardErrorPath = "/tmp/ollama.error.log";
    };
  };
}
