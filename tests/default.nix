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
  overlayChecks = import ./overlays.nix { inherit pkgs; };
  libChecks = import ./lib.nix { inherit pkgs lib inputs; };
  fishChecks = import ./fish.nix { inherit pkgs lib; };
  atuinStorageChecks = import ./atuin-storage.nix { inherit pkgs; };
in
evalChecks // overlayChecks // libChecks // fishChecks // atuinStorageChecks
