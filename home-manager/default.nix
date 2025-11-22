{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}:
let
  hmConfig = import ../config;
  packages = import ./packages { inherit pkgs inputs; };
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
  imports =
    hmConfig
    ++ misc
    ++ modules
    ++ programs
    ++ services
    ++ [
      inputs.agenix.homeManagerModules.default
    ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "claude-code"
        "qwen-code"
        "crush"
      ];
  };

  nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlays.default ];

  home.username = username;
  home.homeDirectory = lib.mkIf pkgs.stdenv.isLinux "/home/${username}";
  home.packages = packages;
  home.stateVersion = "24.11";

  programs.yek.enable = true;

  accounts.email.accounts = {
    Gmail = {
      primary = true;
      flavor = "gmail.com";
      realName = "Shun Kakinoki";
      address = "shunkakinoki@gmail.com";
    };
  };
}
