{
  inputs,
  username,
  system,
  isRunner ? false,
}:
let
  inherit (inputs) home-manager;
in
home-manager.lib.homeManagerConfiguration {
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  extraSpecialArgs = {
    inherit
      inputs
      username
      isRunner
      system
      ;
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
    { nixpkgs.system = system; }
  ];
}
