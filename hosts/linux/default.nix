{
  inputs,
  username,
  system,
  pkgs,
  lib,
  isRunner ? false,
}:
let
  inherit (inputs) home-manager;
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit
      inputs
      username
      isRunner
      system
      pkgs
      ;
  };
  modules = [
    ../../home-manager/default.nix
    {
      home = {
        username = username;
        homeDirectory = lib.mkForce (if username == "root" then "/root" else "/home/${username}");
      };
      programs.home-manager.enable = true;
    }
  ];
}
