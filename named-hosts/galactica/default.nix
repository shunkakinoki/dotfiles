{
  inputs,
  username,
  ...
}:

inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    (import ../../hosts/darwin { inherit inputs username; })
    inputs.agenix.nixosModules.default

    {
      age.secrets = import ./secrets.nix;
      age.secrets."id_ed25519" = {
        file = ./keys/id_ed25519.age;
        owner = username;
      };

      home-manager.users.${username} =
        { pkgs, ... }:
        {
          programs.ssh = {
            enable = true;
            identities = {
              "id_ed25519" = {
                keyFile = config.age.secrets."id_ed25519".path;
              };
            };
          };
        };
    }
  ];
}
