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
  herdrNeedsIdentity = enabled && (host.isKamino || host.isMatic || host.isKyber);
  homeDir = config.home.homeDirectory;
  envFile = "${homeDir}/.config/agenix/agents-prd.env";
  identityPath =
    if host.isKamino then "/etc/ssh/ssh_host_ed25519_key" else "${homeDir}/.ssh/id_ed25519";
in
{
  age.identityPaths = lib.mkIf enabled (lib.mkDefault [ identityPath ]);
  age.secrets."agents-prd.env" = lib.mkIf enabled {
    file = secretFile;
    path = envFile;
    mode = "0400";
  };
  # The shared dotenv printer loads this file in fresh Bash, Zsh, and Fish sessions.
  # The running Herdr process stays up; this file is picked up on its next start.
  # Guard the whole unit, not its fields: a field-level mkIf still declares the
  # herdr-server key, and Home Manager renders it as an empty, masking unit.
  systemd.user.services.herdr-server = lib.mkIf herdrNeedsIdentity {
    Unit.After = lib.mkAfter [ "agenix.service" ];
    Unit.Wants = lib.mkAfter [ "agenix.service" ];
    Service.EnvironmentFile = lib.mkAfter [ "-${envFile}" ];
  };
}
