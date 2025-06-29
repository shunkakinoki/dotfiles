{
  inputs,
  username,
  ...
}:
let
  darwin-modules = import ../../hosts/darwin { inherit inputs username; };
in
inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  specialArgs = darwin-modules.specialArgs;
  modules = darwin-modules.modules ++ [
    {
      age.identityPaths = [ "/Users/${username}/.ssh/id_ed25519" ];
      age.secrets = import ./secrets.nix;
      home-manager.users.${username} = { pkgs, config, ... }: {
        programs.ssh = {
          enable = true;
          matchBlocks = {
            "*" = {
              identityFile = inputs.nixpkgs.lib.mkForce "/run/agenix/keys/id_ed25519.age";
            };
          };
        };
      };
    }
  ];
}
