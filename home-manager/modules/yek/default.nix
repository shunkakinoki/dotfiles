{
  pkgs,
  config,
  ...
}:

let
  # Determine the target platform string
  target =
    if pkgs.stdenv.isDarwin then
      (if pkgs.stdenv.isAarch64 then "aarch64-apple-darwin" else "x86_64-apple-darwin")
    else
      (if pkgs.stdenv.isAarch64 then "aarch64-unknown-linux-gnu" else "x86_64-unknown-linux-gnu");

  # Install script with tool paths substituted
  installYekScript = pkgs.replaceVars ./install-yek.sh {
    target = target;
    curl = "${pkgs.curl}/bin/curl";
    grep = "${pkgs.gnugrep}/bin/grep";
    cut = "${pkgs.coreutils}/bin/cut";
    mktemp = "${pkgs.coreutils}/bin/mktemp";
    tar = "${pkgs.gnutar}/bin/tar";
    install = "${pkgs.coreutils}/bin/install";
  };

  # Create install-yek as a standalone script
  installScript = pkgs.writeScriptBin "install-yek" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash ${installYekScript} "$@"
  '';

  # Wrapper script with install-yek path substituted
  yekWrapperScript = pkgs.replaceVars ./yek.sh {
    install_yek = "${installScript}/bin/install-yek";
  };

  # Create yek wrapper as a standalone script
  yekWrapper = pkgs.writeScriptBin "yek" ''
    #!${pkgs.bash}/bin/bash
    exec ${pkgs.bash}/bin/bash ${yekWrapperScript} "$@"
  '';
in
{
  home.packages = [
    yekWrapper
    installScript
  ];

  # Install yek on activation
  home.activation.installYek = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.local/bin/yek" ]; then
      $DRY_RUN_CMD ${installScript}/bin/install-yek || echo "⚠️ Failed to install yek. You can install it later by running: install-yek"
    fi
  '';
}
