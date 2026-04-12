{
  config,
  lib,
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
    database_connection_string = "";
    deployment_mode = if host.isKyber then "authenticated" else "local_trusted";
    host = if host.isKyber then "0.0.0.0" else "127.0.0.1";
    allowed_hostname = if host.isKyber then "paperclip.shunkakinoki.com" else "";
    is_kyber = if host.isKyber then "true" else "false";
  };
in
{
  home.activation.paperclipConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${setupScript} || true
  '';
}
