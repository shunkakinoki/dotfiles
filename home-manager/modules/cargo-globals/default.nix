{ config, pkgs, ... }:
{
  # Install cargo global packages from Cargo.toml using home-manager activation
  home.activation.installCargoGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.rustup}/bin:${pkgs.cargo}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.gcc}/bin:${pkgs.pkg-config}/bin:$PATH
    export CARGO_HOME="$HOME/.cargo"
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.libiconv.dev}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export OPENSSL_DIR="${pkgs.openssl.dev}"
    export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
    export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
    export LIBRARY_PATH="${pkgs.libiconv.out}/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
    export CPATH="${pkgs.libiconv.dev}/include${CPATH:+:$CPATH}"
    export LDFLAGS="-L${pkgs.libiconv.out}/lib ${LDFLAGS:-}"
    export CPPFLAGS="-I${pkgs.libiconv.dev}/include ${CPPFLAGS:-}"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-cargo-globals.sh}
  '';

  # Add cargo bin to PATH
  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
