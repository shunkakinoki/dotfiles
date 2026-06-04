{ lib, ... }: {
  home.file.".ssh/rc" = {
    source = ./rc;
    force = true;
  };
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.local" ];
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
      "kyber" = {
        HostName = "kyber.tail950b36.ts.net";
        User = "ubuntu";
        IdentityFile = [ "~/.ssh/id_rsa" ];
        IdentitiesOnly = "yes";
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
