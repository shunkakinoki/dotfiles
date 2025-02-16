{ config, ... }:
{
  home.file.".ssh/rc" = {
    source = config.lib.file.mkOutOfStoreSymlink ./rc;
  };
  programs.ssh = {
    enable = true;
    includes = [ "~/.ssh/config.local" ];
    serverAliveInterval = 60;
    matchBlocks = {
      "*" = {
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
        extraOptions = {
          ControlMaster = "auto";
          ControlPath = "~/.ssh/github.sock";
          ControlPersist = "3m";
        };
      };
    };
  };
}
