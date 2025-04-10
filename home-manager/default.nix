{
  system,
  nixpkgs,
  lib ? nixpkgs.lib,
}:
let
  # nvfetcher
  # sources = pkgs.callPackage ../_sources/generated.nix { };

  # config
  config = import ../config;

  # packages
  overlay = import ./overlay;
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = overlay;
  };
  packages = import ./packages { inherit pkgs; };

  # misc
  misc = import ./misc;

  # modules
  modules = import ./modules;

  # Import programs
  programs = import ./programs {
    inherit lib pkgs;
    sources = { };
  };

  # services
  services = import ./services {
    inherit pkgs;
  };

in
{
  imports = config ++ misc ++ modules ++ programs ++ services;

  home.stateVersion = "24.11";
  home.packages = packages;

  accounts.email.accounts = {
    Gmail = {
      primary = true;
      flavor = "gmail.com";
      realName = "Shun Kakinoki";
      address = "shunkakinoki@gmail.com";
    };
  };
}
