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
  fishChecks = import ./fish.nix { inherit pkgs lib; };
  kyberWriterGuardChecks = import ./kyber-writer-guard.nix { inherit pkgs; };
in
evalChecks // overlayChecks // libChecks // fishChecks // kyberWriterGuardChecks
