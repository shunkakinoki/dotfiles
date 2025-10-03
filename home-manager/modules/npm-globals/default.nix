{ config, lib, pkgs, ... }:
{
  # Install npm global packages from package.json using home-manager activation
  home.activation.installNpmGlobals = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.nodejs_20}/bin:${pkgs.corepack}/bin:$PATH
    export PNPM_HOME="$HOME/.local/share/pnpm"

    # Enable corepack for pnpm
    ${pkgs.corepack}/bin/corepack enable

    # Install global packages from package.json if it exists
    PACKAGE_JSON="${config.home.homeDirectory}/dotfiles/package.json"
    if [ -f "$PACKAGE_JSON" ]; then
      echo "Installing npm global packages from package.json..."
      cd "${config.home.homeDirectory}/dotfiles"
      ${pkgs.corepack}/bin/pnpm install --global \
        $(${pkgs.jq}/bin/jq -r '.dependencies | keys[]' "$PACKAGE_JSON") 2>/dev/null || true
    fi
  '';

  # Add pnpm bin to PATH
  home.sessionPath = [
    "$HOME/.local/share/pnpm"
  ];
}
