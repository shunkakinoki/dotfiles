{
  inputs,
  username,
  hostname ? "aarch64-darwin",
  isRunner ? false,
}:
let
  inherit (inputs) nix-darwin home-manager;
  system = "aarch64-darwin";
  configuration =
    { ... }:
    {
      networking.hostName = hostname;
      users.users.${username}.home = "/Users/${username}";
      system.stateVersion = 4;
    };
in
nix-darwin.lib.darwinSystem {
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
        inherit inputs username system;
        lib = inputs.nixpkgs.lib;
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        config = { };
      };
    }
  ];
}
