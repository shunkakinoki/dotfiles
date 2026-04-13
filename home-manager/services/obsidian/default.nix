{
  config,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs) lib;
  inherit (inputs) host;

  # Obsidian 1.12+ ships its official CLI as the `obsidian` binary
  # (https://help.obsidian.md/cli). The CLI subcommands still load the
  # full Electron asar, so they need a display server. We wrap the real
  # binary in `xvfb-run` so each invocation gets an ephemeral virtual X
  # server, letting the CLI run on a headless host.
  homeDir = config.home.homeDirectory;

  obsidianHeadless = pkgs.writeShellScriptBin "obsidian" (
    builtins.readFile (
      pkgs.replaceVars ./obsidian-headless.sh {
        xvfbRun = pkgs.xvfb-run;
        inherit (pkgs) obsidian;
        inherit homeDir;
      }
    )
  );

  # Trigger obsidian-git's auto-backup via CDP. The Electron renderer's
  # setTimeout doesn't fire under headless xvfb (futex blocks the event
  # loop), but CDP uses IPC and bypasses it. All git operations still
  # run through the obsidian-git plugin.
  obsidianGitTrigger = pkgs.writeShellScriptBin "obsidian-git-trigger" (
    builtins.readFile (
      pkgs.replaceVars ./obsidian-git-trigger.sh {
        inherit (pkgs) curl jq websocat;
      }
    )
  );
in
# Only enable on kyber (gateway host) - desktops already get pkgs.obsidian
# directly via home-manager/packages/default.nix.
lib.mkIf host.isKyber {
  home.packages = [
    obsidianHeadless
    pkgs.dejavu_fonts
    pkgs.fontconfig
  ];

  systemd.user.services.obsidian = {
    Unit = {
      Description = "Obsidian headless daemon (xvfb-run CLI socket)";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${obsidianHeadless}/bin/obsidian";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.obsidian-git-trigger = {
    Unit = {
      Description = "Trigger obsidian-git auto-backup via CDP";
      After = [ "obsidian.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${obsidianGitTrigger}/bin/obsidian-git-trigger";
    };
  };

  systemd.user.timers.obsidian-git-trigger = {
    Unit = {
      Description = "Trigger obsidian-git auto-backup every 3 minutes";
    };
    Timer = {
      OnBootSec = "2min";
      OnUnitActiveSec = "3min";
      Unit = "obsidian-git-trigger.service";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
