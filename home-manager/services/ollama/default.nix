{ pkgs, inputs, ... }:
let
  inherit (pkgs) lib;
  inherit (inputs.host) isMatic;

  # Per-host ollama package:
  #   AMD GPU (ROCm): ollama-rocm (matic)
  #   NVIDIA GPU (CUDA): ollama-cuda
  #   CPU fallback: ollama
  ollamaPackage =
    if isMatic then
      pkgs.ollama-rocm
    # else if isNvidiaHost then pkgs.ollama-cuda
    else
      pkgs.ollama;

  ollamaEnv =
    if isMatic then
      [
        "OLLAMA_HOST=0.0.0.0"
        "HSA_OVERRIDE_GFX_VERSION=11.5.0"
      ]
    else
      [
        "OLLAMA_HOST=0.0.0.0"
      ];
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
      ExecStart = "${ollamaPackage}/bin/ollama serve";
      Environment = ollamaEnv;
      Restart = "always";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
