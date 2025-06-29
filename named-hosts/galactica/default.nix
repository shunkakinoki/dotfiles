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
      home-manager.users.${username} = { pkgs, config, ... }: {
        programs.ssh = {
          enable = true;
          matchBlocks = {
            "*" = {
              identityFile = inputs.nixpkgs.lib.mkForce "/run/agenix/keys/id_ed25519.age";
              extraOptions = {
                AddKeysToAgent = "yes";
                UseKeychain = "yes";
              };
            };
          };
        };
        programs.git = {
          signing = {
            signByDefault = true;
            key = "~/.ssh/id_ed25519";
          };
          extraConfig = {
            commit.gpgSign = true;
            gpg.format = "ssh";
            gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
            user.signingKey = "~/.ssh/id_ed25519";
          };
        };
        home.file.".ssh/allowed_signers" = {
          text = "shunkakinoki@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEKze2jlpV7SyTKA2ezqbumpCiDn+5Sj4z5SxrqfzesX shunkakinoki@gmail.com";
        };
        
        # Environment variables for SSH agent
        home.sessionVariables = {
          GPG_TTY = "$(tty)";
        };
        
        # Configure pinentry for macOS
        programs.gpg = {
          enable = true;
          settings = {
            pinentry-program = "${pkgs.pinentry_mac}/bin/pinentry-mac";
          };
        };
        
        # SSH configuration for macOS keychain integration
        home.file.".ssh/config" = {
          text = ''
            Host *
              AddKeysToAgent yes
              UseKeychain yes
              IdentitiesOnly yes
          '';
        };
      };
    }
  ];
}
