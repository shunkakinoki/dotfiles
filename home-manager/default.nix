{
  # Accept standard Home Manager arguments + inputs from extraSpecialArgs
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

  # config - Assuming ../config contains a list of module paths or attribute sets
  hmConfig = import ../config;

  # Define packages using the provided pkgs
  overlay = import ./overlay; # Ensure overlay is compatible if needed, or adjust pkgs in flake.nix
  packages = import ./packages { inherit pkgs; };

  # misc
  misc = import ./misc; # Ensure these expect pkgs, lib if necessary

  # modules
  modules = import ./modules; # Ensure these expect pkgs, lib if necessary

  # Import programs, pass necessary args
  programs = import ./programs {
    inherit lib pkgs;
    sources = { }; # Pass actual sources if needed, potentially from inputs
  };

  # services
  services = import ./services {
    inherit pkgs; # Ensure these expect pkgs, lib if necessary
  };

in
{
  # Import the collected modules
  imports = hmConfig ++ misc ++ modules ++ programs ++ services;

  # Set the username from extraSpecialArgs
  home.username = username;

  # Set the home directory based on the username
  home.homeDirectory = "/home/${username}";

  # Use packages defined above
  home.packages = packages;

  # Keep existing configurations
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
