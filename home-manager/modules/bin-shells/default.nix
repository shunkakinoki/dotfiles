{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
in
{
  config = lib.mkIf isLinux {
    home.activation.binShells = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${pkgs.bash}/bin/bash" "${pkgs.fish}/bin/fish" "${pkgs.zsh}/bin/zsh"
    '';
  };
}
