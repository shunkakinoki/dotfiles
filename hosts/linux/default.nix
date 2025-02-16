{
  inputs,
  username,
  hostname ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) nixpkgs home-manager;
  system = "x86_64-linux";
  configuration =
    { ... }:
    {
      networking.hostName = hostname;
      users.users.${username} = {
        isNormalUser = true;
        home = "/Users/${username}";
      };
    };
in
nixpkgs.lib.nixosSystem {
  inherit system;
  lib = nixpkgs.lib;
  specialArgs = {
    inherit username isRunner;
  };
  modules = [
    configuration
    home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "backup";
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit system;
        nixpkgs = nixpkgs;
      };
    }
  ];
}
