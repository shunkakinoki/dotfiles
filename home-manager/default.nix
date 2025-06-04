{
  config,
  pkgs,
  lib,
  inputs,
  username,
  system,
  ...
}:
let
  hmConfig = import ../config;
  overlay = import ./overlay;
  packages = import ./packages { inherit pkgs inputs system; };
  misc = import ./misc;
  modules = import ./modules;
  programs = import ./programs {
    inherit lib pkgs;
    sources = { };
  };
  services = import ./services {
    inherit pkgs;
  };
in
{
  imports = hmConfig ++ misc ++ modules ++ programs ++ services;

  home.username = username;
  home.homeDirectory = lib.mkIf pkgs.stdenv.isLinux "/home/${username}";
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
