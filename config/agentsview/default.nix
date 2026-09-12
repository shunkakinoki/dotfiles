{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  toolPath = lib.makeBinPath [
    pkgs.dasel
    pkgs.jq
    pkgs.coreutils
    pkgs.python3
  ];
in
lib.mkIf inputs.host.isKyber {
  # Merge into the writable config to preserve AgentsView's generated token.
  home.activation.agentsviewProviderSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${toolPath}:$PATH"
    $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${./activate.sh}" \
      "${config.home.homeDirectory}/.agentsview/config.toml" \
      antigravity
  '';
}
