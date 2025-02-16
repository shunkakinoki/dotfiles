{
  lib,
  pkgs,
  sources,
}:
let
  fish = import ./fish;
  gh = import ./gh;
  go = import ./go;
  rust = import ./rust;
  starship = import ./starship;
  zsh = import ./zsh { inherit lib pkgs; };
in
[
  fish
  gh
  go
  rust
  starship
  zsh
]
