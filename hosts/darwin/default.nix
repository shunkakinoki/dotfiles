{
  inputs,
  username,
  hostname ? "aarch64-darwin",
  isRunner ? false,
}:
let
  inherit (inputs)
    home-manager
    agenix
    ;
  system = "aarch64-darwin";
  overlays = import ../../overlays { inherit inputs; };
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };
  configuration = _: {
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
      nixpkgs.pkgs = pkgs;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.useGlobalPkgs = true;
      home-manager.sharedModules = [
        {
          home.activation.removeBackups = {
            before = [ "checkLinkTargets" ];
            after = [ ];
            data = ''
              ${pkgs.bash}/bin/bash ${./activate-remove-backups.sh}
            '';
          };
        }
      ];
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit inputs username pkgs;
        inherit (pkgs) lib;
        config = { };
      };
    }
  ];
}
