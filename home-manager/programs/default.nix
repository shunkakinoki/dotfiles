{
  lib,
  pkgs,
  sources,
}:
let
  gh = import ./gh { inherit lib pkgs; };
  starship = import ./starship { inherit lib pkgs; };
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  gh
  starship
  zsh
]
