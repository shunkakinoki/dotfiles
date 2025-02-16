{
  lib,
  pkgs,
  sources,
}:
let
  dust = import ./dust;
  fish = import ./fish;
  gh = import ./gh;
  go = import ./go;
  starship = import ./starship;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  dust
  fish
  gh
  go
  starship
  zsh
]
