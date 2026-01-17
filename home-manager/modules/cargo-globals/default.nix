{ config, pkgs, ... }:
{
  # Install cargo global packages from Cargo.toml using home-manager activation
  home.activation.installCargoGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.rustup}/bin:${pkgs.cargo}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:$PATH
    export CARGO_HOME="$HOME/.cargo"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-cargo-globals.sh}
  '';

  # Add cargo bin to PATH
  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
