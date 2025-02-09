{
  lib,
  pkgs,
  sources,
}:
let
  gh = import ./gh;
  starship = import ./starship;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  gh
  starship
  zsh
]
