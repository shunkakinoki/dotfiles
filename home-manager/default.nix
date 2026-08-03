{
  config,
  pkgs,
  lib,
  inputs,
  username,
  isRunner ? false,
  ...
}:
let
  hmConfig = import ../config { inherit inputs; };
  modules = import ./modules;
  nix = import ./nix;
  packages = import ./packages { inherit pkgs inputs isRunner; };
  programs = import ./programs {
    inherit config lib pkgs;
    sources = { };
  };
  services = import ./services {
    inherit
      config
      lib
      pkgs
      inputs
      ;
  };
in
{
  imports =
    hmConfig
    ++ modules
    ++ nix
    ++ programs
    ++ services
    ++ [
      inputs.agenix.homeManagerModules.default
      inputs.noctalia-shell.homeModules.default
    ]
    ++ lib.optionals (pkgs.stdenv.isLinux && inputs.host.isDesktop) [
      inputs.handy.homeManagerModules.default
      {
        services.handy = {
          enable = true;
          package = inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.handy;
        };
      }
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
