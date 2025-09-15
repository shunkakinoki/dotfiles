let
  nixpkgs = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixpkgs-unstable.tar.gz";
  overlays = import ./home-manager/overlay/default.nix;
  pkgs = import nixpkgs { inherit overlays; };
in
  pkgs.buildEnv {
    name = "test-go-env";
    paths = [ pkgs.go pkgs.go_1_24 ];
  }
