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
      age.secrets = builtins.mapAttrs (name: value: { file = value.file; }) (import ./secrets.nix);
      home-manager.users.${username} =
        { pkgs, config, ... }:
        {
          programs.ssh = {
            enable = true;
            matchBlocks = {
              "*" = {
                identityFile = inputs.nixpkgs.lib.mkForce " ~/.ssh/id_rsa";
                extraOptions = {
                  AddKeysToAgent = "yes";
                  UseKeychain = "yes";
                };
              };
            };
          };
          programs.gpg = {
            enable = true;
            settings = {
              default-key = "shunkakinoki@gmail.com";
            };
          };

          programs.git = {
            signing = {
              signByDefault = true;
              key = "shunkakinoki@gmail.com";
            };
            settings = {
              commit = {
                gpgSign = true;
              };
              tag = {
                gpgSign = true;
              };
            };
          };

          # GPG agent configuration with pinentry
          services.gpg-agent = {
            enable = true;
            enableSshSupport = false;
            pinentry.package = pkgs.pinentry_mac;
            defaultCacheTtl = 1800;
            maxCacheTtl = 7200;
          };

          # Environment variables for GPG
          home.sessionVariables = {
            GPG_TTY = "$(tty)";
          };
        };
    }
  ];
}
