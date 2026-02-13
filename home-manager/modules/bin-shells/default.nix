{ lib, pkgs, ... }:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  config = lib.mkIf isLinux {
    home.activation.binShells = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      /run/wrappers/bin/sudo mkdir -p /bin
      /run/wrappers/bin/sudo ln -sf ${pkgs.bash}/bin/bash /bin/bash
      /run/wrappers/bin/sudo ln -sf ${pkgs.fish}/bin/fish /bin/fish
      /run/wrappers/bin/sudo ln -sf ${pkgs.zsh}/bin/zsh /bin/zsh
    '';
  };
}
