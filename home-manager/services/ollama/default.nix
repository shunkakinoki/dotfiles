{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
{
  launchd.agents.ollama = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/ollama"
        "serve"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      EnvironmentVariables.OLLAMA_HOST = "0.0.0.0";
      StandardOutPath = "/tmp/ollama.log";
      StandardErrorPath = "/tmp/ollama.error.log";
    };
  };

  systemd.user.services.ollama = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Ollama AI model server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.ollama}/bin/ollama serve";
      Environment = "OLLAMA_HOST=0.0.0.0";
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
