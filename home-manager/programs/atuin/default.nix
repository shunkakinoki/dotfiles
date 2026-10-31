{ lib, pkgs, ... }:
let
  # Threads (agent session capture/resume) shipped in 18.24; older builds
  # silently ignore the [threads] table and stop capturing.
  minVersion = "18.24.0";
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.atuin.version minVersion;
      message = "atuin ${pkgs.atuin.version} < ${minVersion}: Threads capture needs a newer nixpkgs.";
    }
  ];

  programs.atuin = {
    enable = true;
    package = pkgs.atuin;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    # Threads are captured by the daemon, which also takes over syncing.
    daemon.enable = true;
    settings = {
      auto_sync = true;
      sync_frequency = "3m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
      filter_mode = "global";
      # Applying multi-million-record thread syncs runs queries for 15s+ on a
      # large history.db; the 2s default aborts sync with "pool timed out".
      local_timeout = 120;
      sync = {
        records = true;
      };
      threads = {
        capture = true;
        capture_tools = true;
      };
    };
  };
}
