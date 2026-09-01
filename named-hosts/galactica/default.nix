{
  inputs,
  username,
  ...
}:
let
  host = (import ../../lib/host.nix) // {
    isGalactica = true;
  };
  darwin-modules = import ../../hosts/darwin {
    inherit username;
    inputs = inputs // {
      inherit host;
    };
    hostname = "galactica";
  };
in
inputs.nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  inherit (darwin-modules) specialArgs;
  modules = darwin-modules.modules ++ [
    {
      home-manager.extraSpecialArgs = {
        isRunner = false;
        inputs = inputs // {
          inherit host;
        };
      };
      age.identityPaths = [ "/Users/${username}/.ssh/id_ed25519" ];
      age.secrets = builtins.mapAttrs (_: value: { inherit (value) file; }) (import ./secrets.nix);

      # The standalone macOS Tailscale app cannot host Tailscale SSH. Enable
      # Apple's SSH server so Galactica remains reachable over its tailnet IP.
      services.openssh.enable = true;

      home-manager.users.${username} =
        { pkgs, ... }:
        {
          programs.ssh = {
            enable = true;
            settings = {
              "*" = {
                AddKeysToAgent = "yes";
                UseKeychain = "yes";
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
              commit.gpgSign = true;
              tag.gpgSign = true;
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

        };
    }
  ];
}
