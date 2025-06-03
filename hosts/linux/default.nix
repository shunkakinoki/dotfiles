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
  inherit pkgs lib;
  extraSpecialArgs = {
    inherit
      inputs
      username
      isRunner
      system
      pkgs
      lib
      ;
  };
  modules = [
    ../../home-manager/default.nix
    {
      home = {
        username = username;
        homeDirectory = "/home/${username}";
      };
      programs.home-manager.enable = true;
    }
  ];
}
