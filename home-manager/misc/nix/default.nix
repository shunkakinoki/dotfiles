{ pkgs, ... }:
{
  nix = {
    package = pkgs.nix;
    enable = true;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
