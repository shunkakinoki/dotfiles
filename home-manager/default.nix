{
  system,
  nixpkgs,
}:
let
  # nvfetcher
  # sources = pkgs.callPackage ../_sources/generated.nix { };

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
  # modules = modules ++ [ import ./programs ];

  # services
  # services = import ./services;

in
{
  imports = misc ++ modules;

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
