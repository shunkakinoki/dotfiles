{
  inputs,
  username,
  hostname ? "aarch64-darwin",
  isRunner ? false,
}:
let
  inherit (inputs) nix-darwin home-manager agenix;
  system = "aarch64-darwin";
  configuration =
    { ... }:
    {
      networking.hostName = hostname;
      users.users.${username}.home = "/Users/${username}";
      system.stateVersion = 4;
    };
in
{
  specialArgs = {
    inherit inputs username isRunner;
  };
  modules = [
    configuration
    ../../nix-darwin
    home-manager.darwinModules.home-manager
    agenix.darwinModules.default
    {
      home-manager.backupFileExtension = "hm-backup";
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit inputs username system;
        lib = inputs.nixpkgs.legacyPackages.${system}.lib;
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        config = { };
      };
    }
  ];
}
