{
  inputs,
  username,
  ...
}:
let
  system = "x86_64-linux";
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  overlays = import ../../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit inputs username;
  };
  modules = [
    (import ../shared/live-iso.nix {
      inherit inputs pkgs username;
      hostname = "viper";
      userInitialPassword = "test";
    })
  ];
}
