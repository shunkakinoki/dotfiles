{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Threads (agent session capture/resume) shipped in 18.24; older builds
  # silently ignore the [threads] table and stop capturing.
  minVersion = "18.24.0";
  loginSecret = ../../../named-hosts/atuin/login.age;
  # Kamino workers run as root and their agenix recipients are host keys; some
  # have no ~/.ssh/id_ed25519 at all.
  identityKey =
    if config.home.username == "root" then
      "/etc/ssh/ssh_host_ed25519_key"
    else
      "${config.home.homeDirectory}/.ssh/id_ed25519";
in
{
  assertions = [
    {
      assertion = lib.versionAtLeast pkgs.atuin.version minVersion;
      message = "atuin ${pkgs.atuin.version} < ${minVersion}: Threads capture needs a newer nixpkgs.";
    }
  ];

  home.activation.atuinLogin = lib.mkIf (builtins.pathExists loginSecret) (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../activation/atuin-login.sh}" \
        "${loginSecret}" \
        "${identityKey}" \
        "${pkgs.rage}/bin/rage" \
        "${pkgs.atuin}/bin/atuin" \
        "${pkgs.coreutils}/bin/timeout" \
        "${pkgs.openssh}/bin/ssh-keygen" \
        "shunkakinoki" \
        "${config.home.homeDirectory}/.local/share/atuin"
    ''
  );

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
