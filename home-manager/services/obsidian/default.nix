{
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs) lib;
  inherit (inputs) host;

  obsidianHeadless = pkgs.writeShellScriptBin "obsidian" (
    builtins.readFile (
      pkgs.replaceVars ../../modules/obsidian/obsidian-headless.sh {
        xvfbRun = pkgs.xvfb-run;
        inherit (pkgs) obsidian;
      }
    )
  );
in
lib.mkIf host.isKyber {
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
}
