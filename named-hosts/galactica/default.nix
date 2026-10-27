{
  inputs,
  username,
  ...
}:
let
  tailscaleSetFlags = [
    "--accept-dns=true"
    "--accept-routes=true"
    "--ssh=false"
  ];
  sshAuthorizedKeys = import ../ssh-authorized-keys.nix;
  darwin-modules = import ../../hosts/darwin {
    inherit inputs username tailscaleSetFlags;
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
          host = (import ../../lib/host.nix) // {
            isGalactica = true;
          };
        };
      };
      age.identityPaths = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/Users/${username}/.ssh/id_ed25519"
      ];
      age.secrets = builtins.mapAttrs (
        name: value:
        {
          inherit (value) file;
        }
        // (
          if name == "keys/kyber-writer.age" then
            {
              path = "/Users/${username}/.ssh/id_ed25519_kyber_writer";
              owner = username;
              mode = "0400";
            }
          else
            { }
        )
      ) (import ./secrets.nix);

      # The standalone macOS Tailscale app cannot host Tailscale SSH. Enable
      # Apple's SSH server so Galactica remains reachable over its tailnet IP.
      services.openssh.enable = true;
      users.users.${username}.openssh.authorizedKeys.keys = sshAuthorizedKeys.galactica;

      home-manager.users.${username} =
        { pkgs, lib, ... }:
        {
          programs.ssh = {
            enable = true;
            settings = {
              "*" = {
                AddKeysToAgent = "yes";
                UseKeychain = "yes";
              };
              "kyber" = {
                IdentityFile = lib.mkForce [ "/Users/${username}/.ssh/id_ed25519_kyber_writer" ];
                IdentitiesOnly = "yes";
                IdentityAgent = "none";
                AddKeysToAgent = "no";
                UseKeychain = "no";
              };
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
            defaultCacheTtl = 2147483647;
            maxCacheTtl = 2147483647;
          };

        };
    }
  ];
}
