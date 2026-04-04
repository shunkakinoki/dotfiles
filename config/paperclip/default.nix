{
  config,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) host;
  homeDir = config.home.homeDirectory;
  instanceDir = "${homeDir}/.paperclip/instances/default";

  setupScript = pkgs.replaceVars ./hydrate.sh {
    instance_dir = instanceDir;
    template = "${./config.template.json}";
    sed = "${pkgs.gnused}/bin/sed";
    database_mode = if host.isKyber then "postgres" else "embedded-postgres";
    database_connection_string =
      if host.isKyber then "postgres://postgres:postgres@localhost:5432/paperclip" else "";
    host = if host.isKyber then "0.0.0.0" else "127.0.0.1";
    is_kyber = if host.isKyber then "true" else "false";
  };
in
{
  home.activation.paperclipConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${setupScript} || true
  '';
}
