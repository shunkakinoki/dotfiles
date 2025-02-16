{
  inputs,
  username,
  hostname ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) nix-darwin home-manager;
  system = "x86_64-linux";
  configuration =
    { ... }:
    {
      networking.hostName = hostname;
      users.users.${username}.home = "/Users/${username}";
    };
in
nix-darwin.lib.nixosSystem {
  inherit system;
  inherit (inputs.nixpkgs) lib;
  specialArgs = {
    inherit username isRunner;
  };
  modules = [
    configuration
    ../../nix-darwin
    home-manager.darwinModules.home-manager
    {
      home-manager.backupFileExtension = "backup";
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit system;
        nixpkgs = inputs.nixpkgs;
      };
    }
  ];
}
