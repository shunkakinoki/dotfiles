{ config, ... }:
{
  home.file.".ssh/rc" = {
    source = ./rc;
    force = true;
  };
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [ "~/.ssh/config.local" ];
    matchBlocks = {
      "*" = {
        serverAliveInterval = 60;
        identityFile = "~/.ssh/id_ed25519";
        setEnv = {
          TERM = "xterm-256color";
        };
        sendEnv = [
          "COLORTERM"
        ];
        extraOptions = {
          IgnoreUnknown = "UseKeychain";
          UseKeyChain = "yes";
          # Enable post-quantum key exchange algorithms
          # sntrup761x25519 is a hybrid post-quantum algorithm combining
          # Streamlined NTRU Prime (sntrup761) with X25519
          KexAlgorithms = "sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
          # Prefer modern host key algorithms
          HostKeyAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-256";
          # Prefer modern public key algorithms
          PubkeyAcceptedAlgorithms = "ssh-ed25519-cert-v01@openssh.com,ssh-ed25519,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256-cert-v01@openssh.com,rsa-sha2-256";
        };
      };
      "localhost" = {
        extraOptions = {
          UserKnownHostsFile = "/dev/null";
          StrictHostKeyChecking = "false";
        };
      };
      "github.com" = {
        serverAliveInterval = 0;
        identityFile = "~/.ssh/id_ed25519_github";
        extraOptions = {
          ControlMaster = "auto";
          ControlPath = "~/.ssh/github.sock";
          ControlPersist = "3m";
        };
      };
    };
  };
}
