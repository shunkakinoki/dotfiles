{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  host = inputs.host;
  secretFile = ../../../named-hosts/agents-prd/keys + "/${host.nodeName}.age";
  enabled = pkgs.stdenv.hostPlatform.isLinux && builtins.pathExists secretFile;
  homeDir = config.home.homeDirectory;
  envFile = "${homeDir}/.config/agenix/agents-prd.env";
  identityPath =
    if host.isKamino then "/etc/ssh/ssh_host_ed25519_key" else "${homeDir}/.ssh/id_ed25519";
  loadPosix = ''
    _hm_previous_env_file="''${DOTFILES_ENV_FILE-}"
    _hm_had_env_file="''${DOTFILES_ENV_FILE+x}"
    DOTFILES_ENV_FILE=${envFile}
    _hm_load_env_file
    if [ "$_hm_had_env_file" = x ]; then
      export DOTFILES_ENV_FILE="$_hm_previous_env_file"
    else
      unset DOTFILES_ENV_FILE
    fi
    unset _hm_previous_env_file _hm_had_env_file
  '';
in
{
  age.identityPaths = lib.mkIf enabled (lib.mkDefault [ identityPath ]);
  age.secrets."agents-prd.env" = lib.mkIf enabled {
    file = secretFile;
    path = envFile;
    mode = "0400";
  };

  programs.bash.bashrcExtra = lib.mkIf enabled (lib.mkAfter loadPosix);
  programs.zsh.envExtra = lib.mkIf enabled (lib.mkAfter loadPosix);
  programs.fish.shellInit = lib.mkIf enabled (
    lib.mkAfter ''
      begin
        set -lx DOTFILES_ENV_FILE ${lib.escapeShellArg envFile}
        _hm_load_env_file
      end
    ''
  );

  # The running Herdr process stays up; this file is picked up on its next start.
  systemd.user.services.herdr-server.Service.EnvironmentFile = lib.mkIf (
    enabled && (host.isKamino || host.isMatic || host.isKyber)
  ) (lib.mkAfter [ "-${envFile}" ]);
}
