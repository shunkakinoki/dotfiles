{
  lib,
  pkgs,
  sources,
}:
let
  gh = import ./gh;
  starship = import ./starship;
in
[
  gh
  starship
]
