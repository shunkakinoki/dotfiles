{
  pkgs,
  lib,
  config,
  ...
}:

with lib;

let
  cfg = config.programs.yek;

  # Determine the target platform string
  target =
    if pkgs.stdenv.isDarwin then
      (if pkgs.stdenv.isAarch64 then "aarch64-apple-darwin" else "x86_64-apple-darwin")
    else
      (if pkgs.stdenv.isAarch64 then "aarch64-unknown-linux-gnu" else "x86_64-unknown-linux-gnu");

  # Install script that downloads the latest release
  installScript = pkgs.writeShellScriptBin "install-yek" ''
    set -euo pipefail

    REPO_OWNER="bodo-run"
    REPO_NAME="yek"
    TARGET="${target}"
    ASSET_NAME="yek-''${TARGET}.tar.gz"
    INSTALL_DIR="$HOME/.local/bin"

    mkdir -p "$INSTALL_DIR"

    echo "Fetching latest release info from GitHub..."
    LATEST_URL=$(
        ${pkgs.curl}/bin/curl -s "https://api.github.com/repos/''${REPO_OWNER}/''${REPO_NAME}/releases/latest" |
            ${pkgs.gnugrep}/bin/grep "browser_download_url" |
            ${pkgs.gnugrep}/bin/grep "''${ASSET_NAME}" |
            ${pkgs.coreutils}/bin/cut -d '"' -f 4
    )

    if [ -z "''${LATEST_URL}" ]; then
        echo "Failed to find a release asset named ''${ASSET_NAME} in the latest release."
        exit 1
    fi

    echo "Downloading from: ''${LATEST_URL}"
    cd "$(${pkgs.coreutils}/bin/mktemp -d)"
    ${pkgs.curl}/bin/curl -L -o "''${ASSET_NAME}" "''${LATEST_URL}"

    echo "Extracting archive..."
    PATH="${pkgs.gzip}/bin:$PATH" ${pkgs.gnutar}/bin/tar xzf "''${ASSET_NAME}"

    echo "Installing binary to ''${INSTALL_DIR}..."
    ${pkgs.coreutils}/bin/install -Dm755 yek-''${TARGET}/yek "''${INSTALL_DIR}/yek"

    echo "✅ yek installed successfully to ''${INSTALL_DIR}/yek"
    echo "Version: $(''${INSTALL_DIR}/yek --version)"
  '';

  yekWrapper = pkgs.writeShellScriptBin "yek" ''
    INSTALL_DIR="$HOME/.local/bin"
    YEK_BIN="''${INSTALL_DIR}/yek"

    # Install yek if not present
    if [ ! -f "''${YEK_BIN}" ]; then
      echo "yek not found. Installing latest version..."
      ${installScript}/bin/install-yek
    fi

    # Execute yek with all arguments
    exec "''${YEK_BIN}" "$@"
  '';
in
{
  options.programs.yek = {
    enable = mkEnableOption "yek - serialize text files for LLM consumption";

    package = mkOption {
      type = types.package;
      default = yekWrapper;
      description = "The yek wrapper package";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      installScript
    ];

    # Install yek on activation
    home.activation.installYek = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.local/bin/yek" ]; then
        $DRY_RUN_CMD ${installScript}/bin/install-yek || true
      fi
    '';
  };
}
