{ pkgs, lib, ... }:
let
  # Systemd service file for Docker daemon
  dockerServiceFile = pkgs.writeText "docker.service" (
    builtins.readFile (
      pkgs.replaceVars ./docker.service {
        docker = pkgs.docker;
        coreutils = pkgs.coreutils;
      }
    )
  );

  # Script to ensure user is in docker group and system docker is running
  setupDockerScript = pkgs.writeShellScript "setup-docker" (
    builtins.readFile (
      pkgs.replaceVars ./setup-docker.sh {
        shadow = pkgs.shadow;
        gnugrep = pkgs.gnugrep;
        systemd = pkgs.systemd;
        coreutils = pkgs.coreutils;
        docker_service_file = dockerServiceFile;
      }
    )
  );
in
{
  # Provide setup script for system Docker
  home.packages = lib.mkIf pkgs.stdenv.isLinux [
    (pkgs.writeShellScriptBin "docker-setup" (
      builtins.readFile (
        pkgs.replaceVars ./docker-setup.sh {
          setup_docker_script = setupDockerScript;
        }
      )
    ))
  ];
}
