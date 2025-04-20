{
  inputs,
  username,
  hostname ? "x86_64-linux",
  isRunner ? false,
}:
let
  inherit (inputs) home-manager;
  system = "x86_64-linux";
in
home-manager.lib.homeManagerConfiguration {
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  extraSpecialArgs = {
    inherit inputs username isRunner;
    config = { };
  };
  modules = [
    ../../home-manager/default.nix
    {
      home = {
        username = username;
        homeDirectory = "/home/${username}";
      };
      programs.home-manager.enable = true;
    }
  ];
}
