{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}:
let
  # nvfetcher
  # sources = pkgs.callPackage ../_sources/generated.nix { };

  hmConfig = import ../config;

  overlay = import ./overlay;
  packages = import ./packages { inherit pkgs; };

  misc = import ./misc;

  modules = import ./modules;

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
  imports = hmConfig ++ misc ++ modules ++ programs ++ services;

  home.username = username;

  home.homeDirectory = "/home/${username}";

  home.packages = packages;

  home.stateVersion = "24.11";

  accounts.email.accounts = {
    Gmail = {
      primary = true;
      flavor = "gmail.com";
      realName = "Shun Kakinoki";
      address = "shunkakinoki@gmail.com";
    };
  };
}
