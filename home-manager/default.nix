{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}:
let
  hmConfig = import ../config { inherit inputs; };
  packages = import ./packages { inherit pkgs inputs; };
  modules = import ./modules;
  programs = import ./programs {
    inherit config lib pkgs;
    sources = { };
  };
  services = import ./services {
    inherit config lib pkgs;
  };
in
{
  imports =
    hmConfig
    ++ [ ./nix ]
    ++ modules
    ++ programs
    ++ services
    ++ [
      inputs.agenix.homeManagerModules.default
      inputs.xremap.homeManagerModules.default
    ];

  home.username = username;
  home.homeDirectory = lib.mkIf pkgs.stdenv.isLinux "/home/${username}";
  home.packages = packages;
  home.stateVersion = "24.11";

  # Suppress home-manager manual options.json generation warning.
  manual.manpages.enable = false;

  accounts.email.accounts = {
    Gmail = {
      primary = true;
      flavor = "gmail.com";
      realName = "Shun Kakinoki";
      address = "shunkakinoki@gmail.com";
    };
  };
}
