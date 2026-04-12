{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv) isDarwin;
  libiconvPkgConfigPath = lib.optionalString isDarwin ":${pkgs.libiconv.dev}/lib/pkgconfig";
  libiconvLibraryPath = lib.optionalString isDarwin "${pkgs.libiconv.out}/lib";
  libiconvCPath = lib.optionalString isDarwin "${pkgs.libiconv.dev}/include";
  libiconvLdFlags = lib.optionalString isDarwin "-L${pkgs.libiconv.out}/lib ";
  libiconvCppFlags = lib.optionalString isDarwin "-I${pkgs.libiconv.dev}/include ";
in
{
  # Install cargo global packages from Cargo.toml using home-manager activation
  home.activation.installCargoGlobals = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${pkgs.rustup}/bin:${pkgs.cargo}/bin:${pkgs.rustc}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.gcc}/bin:${pkgs.pkg-config}/bin:${pkgs.perl}/bin:$PATH
    export CARGO_HOME="$HOME/.cargo"
    export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig${libiconvPkgConfigPath}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export OPENSSL_DIR="${pkgs.openssl.dev}"
    export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
    export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
    ${lib.optionalString isDarwin ''export LIBRARY_PATH="${libiconvLibraryPath}''${LIBRARY_PATH:+:$LIBRARY_PATH}"''}
    ${lib.optionalString isDarwin ''export CPATH="${libiconvCPath}''${CPATH:+:$CPATH}"''}
    ${lib.optionalString isDarwin ''export LDFLAGS="${libiconvLdFlags}''${LDFLAGS:-}"''}
    ${lib.optionalString isDarwin ''export CPPFLAGS="${libiconvCppFlags}''${CPPFLAGS:-}"''}
    ${lib.optionalString (!isDarwin) ''export SYSTEMCTL_BIN="${pkgs.systemd}/bin/systemctl"''}
    export RUSTUP_BIN="${pkgs.rustup}/bin/rustup"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${./install-cargo-globals.sh}
  '';

  # Run cargo globals install after login (Linux only - systemd)
  systemd.user.services = lib.mkIf (!isDarwin) {
    install-cargo-globals = {
      Unit = {
        Description = "Install cargo global packages";
        After = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        Environment = [
          "PATH=${pkgs.rustup}/bin:${pkgs.cargo}/bin:${pkgs.rustc}/bin:${pkgs.dasel}/bin:${pkgs.jq}/bin:${pkgs.gcc}/bin:${pkgs.pkg-config}/bin:${pkgs.perl}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
          "CARGO_HOME=%h/.cargo"
          "HOME=%h"
          "PKG_CONFIG_PATH=${pkgs.openssl.dev}/lib/pkgconfig${libiconvPkgConfigPath}"
          "OPENSSL_DIR=${pkgs.openssl.dev}"
          "OPENSSL_LIB_DIR=${pkgs.openssl.out}/lib"
          "OPENSSL_INCLUDE_DIR=${pkgs.openssl.dev}/include"
        ];
        ExecStart = "${pkgs.bash}/bin/bash ${./install-cargo-globals.sh}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  # Add cargo bin to PATH
  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
}
