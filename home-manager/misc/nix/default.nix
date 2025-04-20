{ lib, pkgs, ... }:
{
  nix = {
    package = lib.mkDefault pkgs.nix;
    enable = true;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
