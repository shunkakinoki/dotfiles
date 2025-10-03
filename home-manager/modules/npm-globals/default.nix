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
      ${pkgs.bun}/bin/bun install --global \
        $(${pkgs.jq}/bin/jq -r '.dependencies | keys[]' "$PACKAGE_JSON") 2>/dev/null || true
    fi
  '';

  # Add bun bin to PATH
  home.sessionPath = [
    "$HOME/.bun/bin"
  ];
}
