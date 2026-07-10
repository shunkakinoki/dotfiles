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

  # Sync the vault directly with Git. Headless Obsidian does not reliably
  # load community plugins, so Git durability must not depend on its renderer.
  wikiGitSync = pkgs.writeShellScriptBin "wiki-git-sync" (
    builtins.readFile (
      pkgs.replaceVars ./obsidian-git-trigger.sh {
        inherit (pkgs) coreutils git;
        utilLinux = pkgs.util-linux;
        vaultDir = "${homeDir}/ghq/github.com/shunkakinoki/wiki";
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
      Description = "Commit and push the memory wiki vault";
      After = [ "network-online.target" ];
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${wikiGitSync}/bin/wiki-git-sync";
    };
  };

  systemd.user.timers.obsidian-git-trigger = {
    Unit = {
      Description = "Commit and push the memory wiki every 3 minutes";
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
