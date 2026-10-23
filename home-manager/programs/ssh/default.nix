{
  config,
  lib,
  pkgs,
  ...
}:
let
  knownHosts = pkgs.writeText "ssh-known-hosts" (import ./known-hosts.nix);
  pinKnownHostsScript = pkgs.replaceVars ./pin-known-hosts.sh {
    awk = "${pkgs.gawk}/bin/awk";
  };
  hostAliases = import ./host-aliases.nix config.programs.ssh.settings;
in
{
  home.shellAliases = (lib.mapAttrs (_: command: lib.mkDefault command) hostAliases) // {
    # These nodes run Tailscale SSH, which verifies their current host key via
    # the coordination server even after a host has been rebuilt.
    beskar = "tailscale ssh ${config.programs.ssh.settings.beskar.data.User}@beskar";
    matic = "tailscale ssh ${config.programs.ssh.settings.matic.data.User}@matic";
  };

  # Home Manager's Fish shellAliases are interactive-only. Load these host
  # commands in conf.d as well so `fish -c 'beskar ...'` works consistently.
  xdg.configFile."fish/conf.d/ssh-host-commands.fish".text = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: _: "alias ${name} ${lib.escapeShellArg config.home.shellAliases.${name}}"
    ) hostAliases
  );

  home.file.".ssh/rc" = {
    source = ./rc;
  };
  home.activation.caamKnownHosts = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${pinKnownHostsScript} ${knownHosts}
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.local" ];
    # Namespace `devbox create` rewrites ~/.ssh/config, and fails on this
    # read-only file, unless this exact line is already present on its own;
    # `includes` would merge it into one shared Include line.
    extraOptionOverrides.Include = "~/.namespace/ssh/*.ssh";
    settings = {
      "*" = {
        ServerAliveInterval = 60;
        IdentityFile = lib.mkForce [ "~/.ssh/id_ed25519" ];
        SetEnv = {
          TERM = "xterm-256color";
        };
        SendEnv = [ "COLORTERM" ];
        IgnoreUnknown = "UseKeychain";
        UseKeyChain = "yes";
        KexAlgorithms = "sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
        HostKeyAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-256";
        PubkeyAcceptedAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-256";
      };
      "localhost" = {
        UserKnownHostsFile = "/dev/null";
        StrictHostKeyChecking = "false";
      };
      "andor" = {
        HostName = "andor.tail950b36.ts.net";
        User = "ubuntu";
      };
      "beskar" = {
        HostName = "beskar.tail950b36.ts.net";
        User = "ubuntu";
      };
      "galactica" = {
        HostName = "galactica.tail950b36.ts.net";
        User = "shunkakinoki";
      };
      "kyber" = {
        HostName = "kyber.tail950b36.ts.net";
        User = "ubuntu";
        IdentityFile = [ "~/.ssh/id_rsa" ];
        IdentitiesOnly = "yes";
      };
      "matic" = {
        HostName = "matic.tail950b36.ts.net";
        User = "shunkakinoki";
      };
      "github.com" = {
        ServerAliveInterval = 0;
        IdentityFile = [ "~/.ssh/id_ed25519_github" ];
        ControlMaster = "auto";
        ControlPath = "~/.ssh/github.sock";
        ControlPersist = "3m";
      };
    };
  };
}
