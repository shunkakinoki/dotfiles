{
  config,
  lib,
  pkgs,
  isRunner ? false,
  ...
}:
let
  # Systemd service file for Docker daemon
  dockerServiceFile = pkgs.writeText "docker.service" (
    builtins.readFile (
      pkgs.replaceVars ./docker.service {
        inherit (pkgs) docker coreutils;
      }
    )
  );

  # Docker daemon defaults installed on Linux hosts.
  dockerDaemonFile = pkgs.writeText "daemon.json" (builtins.readFile ./daemon.json);

  # Script to ensure user is in docker group and system docker is running
  setupDockerScript = pkgs.writeShellScript "setup-docker" (
    builtins.readFile (
      pkgs.replaceVars ./setup-docker.sh {
        inherit (pkgs)
          shadow
          gnugrep
          systemd
          coreutils
          diffutils
          ;
        docker_service_file = dockerServiceFile;
        docker_daemon_file = dockerDaemonFile;
      }
    )
  );
in
{
  # Provide setup script for system Docker
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isLinux [
    (pkgs.writeShellScriptBin "docker-setup" (
      builtins.readFile (
        pkgs.replaceVars ./docker-setup.sh {
          setup_docker_script = setupDockerScript;
        }
      )
    ))
  ];

  # Keep /etc/systemd/system/docker.service and /etc/docker/daemon.json aligned
  # with the active Nix store paths during automated switches (dotfiles-updater
  # runs `make install`, not `make systemctl-docker`). Otherwise Nix GC removes
  # the previous dockerd path and leaves docker.service failing with 203/EXEC.
  home.activation.setupDocker = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && !isRunner) (
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${setupDockerScript}" --non-interactive
    ''
  );

}
