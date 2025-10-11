{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Install npm global packages from package.json using home-manager activation
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.bun}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"

    # Install global packages from package.json if it exists
    PACKAGE_JSON="${config.home.homeDirectory}/dotfiles/package.json"
    if [ -f "$PACKAGE_JSON" ]; then
      echo "Installing npm global packages from package.json using bun..."
      cd "${config.home.homeDirectory}/dotfiles"

      # Trust postinstall scripts for packages listed in trustedDependencies before installing
      TRUSTED_DEPS=$(${pkgs.jq}/bin/jq -r '.trustedDependencies[]?' "$PACKAGE_JSON" 2>/dev/null)
      if [ -n "$TRUSTED_DEPS" ]; then
        echo "Trusting postinstall scripts for: $TRUSTED_DEPS"
        echo "$TRUSTED_DEPS" | while read -r dep; do
          ${pkgs.bun}/bin/bun pm -g trust "$dep" 2>/dev/null || true
        done
      fi

      ${pkgs.bun}/bin/bun install --global \
        $(${pkgs.jq}/bin/jq -r '.dependencies | keys[]' "$PACKAGE_JSON") 2>/dev/null || true
    fi
  '';

  # Add local and bun bins to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];
}
