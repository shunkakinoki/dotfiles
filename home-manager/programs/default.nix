{
  lib,
  pkgs,
  sources,
}:
let
  dust = import ./dust;
  gh = import ./gh;
  go = import ./go;
  starship = import ./starship;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  dust
  gh
  go
  starship
  zsh
]
