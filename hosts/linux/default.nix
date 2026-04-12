{
  inputs,
  username,
  system ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) home-manager;
  overlays = import ../../overlays { inherit inputs; };
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };
  inherit (pkgs) lib;
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit
      inputs
      username
      isRunner
      pkgs
      ;
  };
  modules = [
    ../../home-manager/default.nix
    {
      home = {
        inherit username;
        homeDirectory = lib.mkForce (if username == "root" then "/root" else "/home/${username}");
        activation.backupExistingFiles = lib.mkForce {
          before = [ "checkLinkTargets" ];
          after = [ ];
          data = ''
            ${pkgs.bash}/bin/bash "${./activate-backup-files.sh}"
          '';
        };
      };
      programs.home-manager.enable = true;
    }
  ];
}
