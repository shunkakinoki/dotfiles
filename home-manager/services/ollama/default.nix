{ pkgs }:
let
  inherit (pkgs) lib writeShellApplication;

  # launchd wrapper so we can reuse the Homebrew-installed ollama binary
  ollamaHomebrew = writeShellApplication {
    name = "ollama-homebrew";
    text = ''
      set -euo pipefail

      if [ -x /opt/homebrew/bin/ollama ]; then
        exec /opt/homebrew/bin/ollama "$@"
      elif [ -x /usr/local/bin/ollama ]; then
        exec /usr/local/bin/ollama "$@"
      else
        echo "ollama binary not found; install it with \"brew install ollama\"" >&2
        exit 1
      fi
    '';
  };
in
lib.mkIf pkgs.stdenv.isDarwin {
  launchd.agents.ollama = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe ollamaHomebrew)
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
