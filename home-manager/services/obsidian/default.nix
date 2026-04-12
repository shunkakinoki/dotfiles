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
      ExecStartPre = "${pkgs.writeShellScript "obsidian-pre" ''
        rm -f ${config.xdg.configHome}/obsidian/SingletonLock
        rm -f ${config.xdg.configHome}/obsidian/SingletonSocket
        rm -f ${config.xdg.configHome}/obsidian/SingletonCookie
      ''}";
      ExecStart = "${obsidianHeadless}/bin/obsidian";
      Restart = "always";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
