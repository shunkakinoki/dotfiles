{
  pkgs,
  lib,
  config,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  # Node versions to pre-install (first one is default)
  nodeVersions = [
    "22"
    "20"
  ];
  defaultVersion = builtins.head nodeVersions;
in
{
  home.packages = with pkgs; [ fnm ];

  xdg.configFile."fish/conf.d/fnm.fish".text = builtins.toString ''
    fnm env --use-on-cd --shell fish | source
  '';

  # Pre-install node versions and set default
  home.activation.fnmSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.fnm}/bin:$PATH"
    export FNM_DIR="${homeDir}/.local/share/fnm"

    # Install each version if not already installed
    ${lib.concatMapStrings (version: ''
      if [ ! -d "$FNM_DIR/node-versions/v${version}"* ]; then
        ${pkgs.fnm}/bin/fnm install ${version} || true
      fi
    '') nodeVersions}

    # Set default version
    ${pkgs.fnm}/bin/fnm default ${defaultVersion} || true

    # Create stable symlink for systemd services
    if [ -d "$FNM_DIR/node-versions" ]; then
      latest_v22=$(ls -d "$FNM_DIR/node-versions/v22"* 2>/dev/null | head -1)
      if [ -n "$latest_v22" ] && [ -d "$latest_v22/installation/bin" ]; then
        mkdir -p "${homeDir}/.local/bin"
        ln -sf "$latest_v22/installation/bin/node" "${homeDir}/.local/bin/node"
      fi
    fi
  '';
}
