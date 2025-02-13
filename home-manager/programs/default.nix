{
  lib,
  pkgs,
  sources,
}:
let
  dust = import ./dust;
  gh = import ./gh;
  starship = import ./starship;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  dust
  gh
  starship
  zsh
]
