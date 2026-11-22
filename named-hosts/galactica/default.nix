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
      # The user key has a passphrase the unattended activation job cannot
      # enter, so system secrets must be encrypted to the host key.
      age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      age.secrets."traces.env" = {
        file = ../traces/keys/traces.env.age;
        path = "/Users/${username}/.config/agenix/traces.env";
        owner = username;
        mode = "0400";
      };

      # The standalone macOS Tailscale app cannot host Tailscale SSH. Enable
      # Apple's SSH server so Galactica remains reachable over its tailnet IP.
      services.openssh.enable = true;
      users.users.${username}.openssh.authorizedKeys.keys = sshAuthorizedKeys.galactica;

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
