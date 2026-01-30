{
  pkgs,
  lib,
  inputs,
  system,
}:
let
  evalChecks = import ./eval.nix {
    inherit
      pkgs
      lib
      inputs
      system
      ;
  };
  overlayChecks = import ./overlays.nix { inherit pkgs lib inputs; };
  libChecks = import ./lib.nix { inherit pkgs lib inputs; };
in
evalChecks // overlayChecks // libChecks
