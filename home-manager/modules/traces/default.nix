{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (inputs) host;
  secretFile = ../../../named-hosts/traces/keys/traces.env.age;
  # Only hosts the ciphertext is encrypted to can decrypt it; any other host
  # would fail agenix on every activation.
  enabled =
    pkgs.stdenv.hostPlatform.isLinux
    && builtins.pathExists secretFile
    && (import ../../../named-hosts/pubkeys.nix) ? ${host.nodeName};
  herdrNeedsKey = enabled && (host.isBeskar || host.isKamino || host.isMatic || host.isKyber);
  homeDir = config.home.homeDirectory;
  envFile = "${homeDir}/.config/agenix/traces.env";
  identityPath =
    if host.isKamino then "/etc/ssh/ssh_host_ed25519_key" else "${homeDir}/.ssh/id_ed25519";
in
{
  age.identityPaths = lib.mkIf enabled (lib.mkDefault [ identityPath ]);
  age.secrets."traces.env" = lib.mkIf enabled {
    file = secretFile;
    path = envFile;
    mode = "0400";
  };
  # Agent hooks inherit Herdr's environment rather than a login shell's.
  systemd.user.services.herdr-server = lib.mkIf herdrNeedsKey {
    Unit.After = lib.mkAfter [ "agenix.service" ];
    Unit.Wants = lib.mkAfter [ "agenix.service" ];
    Service.EnvironmentFile = lib.mkAfter [ "-${envFile}" ];
  };
}
