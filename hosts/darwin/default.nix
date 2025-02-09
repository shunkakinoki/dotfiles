{ inputs, username ? "shunkakinoki", hostname ? "aarch64-darwin" }:
let
  inherit (inputs) nix-darwin home-manager;
  system = "aarch64-darwin";
  configuration =
    { ... }:
    {
      networking.hostName = hostname;
      users.users.${username}.home = "/Users/${username}";
    };
in
nix-darwin.lib.darwinSystem {
  inherit system;
  inherit (inputs.nixpkgs) lib;
  specialArgs = {
    inherit username;
  };
  modules = [
    configuration
    ../../nix-darwin
    home-manager.darwinModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit system;
        nixpkgs = inputs.nixpkgs;
        inherit inputs;
      };
    }
  ];
}
