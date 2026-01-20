{ config, pkgs, ... }:
{
  # Install npm global packages from package.json using home-manager activation
  home.activation.installNpmGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.bun}/bin:${pkgs.jq}/bin:$PATH
    export BUN_INSTALL="$HOME/.bun"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-npm-globals.sh}
  '';

  # Fix bun postinstall failures (e.g., @beads/bd tarball not extracted)
  # Runs after npm globals to extract any tarballs that failed during postinstall
  home.activation.fixBunPostinstall = config.lib.dag.entryAfter [ "installNpmGlobals" ] ''
    BD_BIN_DIR="$HOME/.bun/install/global/node_modules/@beads/bd/bin"
    if [ -d "$BD_BIN_DIR" ]; then
      # Check if tarball exists but binary doesn't
      TARBALL=$(find "$BD_BIN_DIR" -name "beads_*.tar.gz" 2>/dev/null | head -1)
      if [ -n "$TARBALL" ] && [ ! -f "$BD_BIN_DIR/bd" ]; then
        echo "Extracting bd binary from tarball..."
        ${pkgs.gnutar}/bin/tar -xzf "$TARBALL" -C "$BD_BIN_DIR"
        chmod +x "$BD_BIN_DIR/bd" 2>/dev/null || true
      fi
    fi
  '';

  # Add local and bun bins to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
  ];
}
