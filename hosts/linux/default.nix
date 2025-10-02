{
  inputs,
  username,
  system,
  pkgs,
  lib,
  isRunner ? false,
}:
let
  inherit (inputs) home-manager;
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit
      inputs
      username
      isRunner
      system
      pkgs
      ;
  };
  modules = [
    ../../home-manager/default.nix
    {
      home = {
        username = username;
        homeDirectory = lib.mkForce (if username == "root" then "/root" else "/home/${username}");
        activation.backupExistingFiles = lib.mkForce {
          before = [ "checkLinkTargets" ];
          after = [ ];
          data = ''
            # Backup existing bash configuration files
            for file in .bashrc .profile .bash_profile; do
              if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                echo "Backing up existing $file to $file.hm-backup"
                mv "$HOME/$file" "$HOME/$file.hm-backup"
              fi
            done

            # Clean up old backups in .codex
            find ~/.codex -name "*.hm-backup*" -delete 2>/dev/null || true
          '';
        };
      };
      programs.home-manager.enable = true;
    }
  ];
}
