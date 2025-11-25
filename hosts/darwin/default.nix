{
  inputs,
  username,
  hostname ? "aarch64-darwin",
  isRunner ? false,
}:
let
  inherit (inputs)
    nix-darwin
    home-manager
    agenix
    ;
  system = "aarch64-darwin";
  overlays = import ../../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config.allowUnfree = true;
  };
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
      nixpkgs.pkgs = pkgs;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.sharedModules = [
        {
          home.activation.removeBackups = {
            before = [ "checkLinkTargets" ];
            after = [ ];
            data = ''
              find ~/.codex -name "*.hm-backup*" -delete 2>/dev/null || true
            '';
          };
        }
      ];
      home-manager.useUserPackages = true;
      home-manager.users."${username}" = import ../../home-manager {
        inherit inputs username pkgs;
        lib = pkgs.lib;
        config = { };
      };
    }
  ];
}
