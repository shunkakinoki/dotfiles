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
  rust = import ./rust;
  starship = import ./starship;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  dust
  fish
  gh
  go
  rust
  starship
  zsh
]
