{
  config,
  lib,
  pkgs,
  ...
}:
let
  settings = pkgs.replaceVars ./settings.json {
    moshiHook = "${pkgs.moshi-hook}/bin/moshi-hook";
  };
in
{
  # Keep a writable file for tools that use atomic updates, then restore the
  # Nix-rendered configuration on every activation.
  home.activation.geminiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${settings}"
  '';
}
