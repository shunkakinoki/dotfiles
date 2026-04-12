{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  config = lib.mkIf isLinux {
    home.activation.binShells = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" "${pkgs.bash}/bin/bash" "${pkgs.fish}/bin/fish" "${pkgs.zsh}/bin/zsh"
    '';
  };
}
