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
  home.activation.fnmSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.fnm}/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" \
      "${pkgs.fnm}/bin/fnm" \
      "${homeDir}/.local/share/fnm" \
      "${defaultVersion}" \
      ${lib.concatMapStringsSep " " (version: "\"${version}\"") (builtins.tail nodeVersions)}
  '';
}
