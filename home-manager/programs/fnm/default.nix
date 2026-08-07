{
  pkgs,
  lib,
  config,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  fnmDir =
    if pkgs.stdenv.isDarwin then
      "${homeDir}/Library/Application Support/fnm"
    else
      "${homeDir}/.local/share/fnm";
  # Node versions to pre-install (first one is default)
  nodeVersions = [
    "24.14.0"
    "22.21.1"
    "20.19.0"
  ];
  defaultVersion = builtins.head nodeVersions;
in
{
  home.packages = with pkgs; [ fnm ];

  programs.fish.interactiveShellInit = lib.mkAfter ''
    fnm env --use-on-cd --shell fish | source
  '';

  # Pre-install node versions and set default
  home.activation.fnmSetup = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${pkgs.fnm}/bin:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" \
      "${pkgs.fnm}/bin/fnm" \
      "${fnmDir}" \
      "${defaultVersion}" \
      ${lib.concatMapStringsSep " " (version: "\"${version}\"") (builtins.tail nodeVersions)}
  '';
}
