{
  config,
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;
  moshiHookBin =
    if pkgs.stdenv.isDarwin then
      config.lib.file.mkOutOfStoreSymlink "/opt/homebrew/bin/moshi-hook"
    else
      "${pkgs.moshi-hook}/bin/moshi-hook";
in
{
  # Pi/OpenCode/OMP plugins spawn this exact path; PATH is not consulted.
  home.file.".local/bin/moshi-hook" = {
    source = moshiHookBin;
    force = true;
  };

  systemd.user.services.moshi-hook = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Moshi Hook daemon";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.moshi-hook}/bin/moshi-hook serve";
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
