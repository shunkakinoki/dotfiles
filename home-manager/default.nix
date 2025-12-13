{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}:
let
  hmConfig = import ../config;
  packages = import ./packages { inherit pkgs inputs; };
  misc = import ./misc;
  modules = import ./modules;
  programs = import ./programs {
    inherit lib pkgs;
    sources = { };
  };
  services = import ./services {
    inherit pkgs;
  };
in
{
  imports =
    hmConfig
    ++ misc
    ++ modules
    ++ programs
    ++ services
    ++ [
      inputs.agenix.homeManagerModules.default
    ];

  home.username = username;
  home.homeDirectory = lib.mkIf pkgs.stdenv.isLinux "/home/${username}";
  home.packages = packages;
  home.stateVersion = "24.11";

  # Import GPG key from agenix (all systems)
  # Fails silently if SSH key isn't authorized to decrypt
  home.activation.importGpgKey = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    $VERBOSE_ECHO "🔑 Starting GPG key import process..."
    GPG_SECRET_FILE="${config.home.homeDirectory}/dotfiles/named-hosts/galactica/keys/gpg.age"
    GPG_TEMP_FILE="${config.home.homeDirectory}/.config/agenix/gpg.key"

    # Create agenix directory if it doesn't exist
    mkdir -p "${config.home.homeDirectory}/.config/agenix"

    if [[ -f "$GPG_SECRET_FILE" ]]; then
      # Check if key is already imported
      if ! ${pkgs.gnupg}/bin/gpg --list-secret-keys 2>/dev/null | grep -q "C2E97FCFF482925D"; then
        echo "Importing GPG key from agenix..."
        # Try to decrypt - will fail silently if SSH key isn't authorized
        if ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 -o "$GPG_TEMP_FILE" "$GPG_SECRET_FILE" 2>/dev/null; then
          ${pkgs.gnupg}/bin/gpg --batch --import "$GPG_TEMP_FILE" 2>/dev/null
          rm -f "$GPG_TEMP_FILE"
          echo "✅ GPG key imported successfully"
        fi
      else
        $VERBOSE_ECHO "ℹ️  GPG key already imported"
      fi
    fi
  '';

  programs.yek.enable = true;

  accounts.email.accounts = {
    Gmail = {
      primary = true;
      flavor = "gmail.com";
      realName = "Shun Kakinoki";
      address = "shunkakinoki@gmail.com";
    };
  };
}
