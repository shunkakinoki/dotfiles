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

  configJson = builtins.toJSON {
    database =
      if host.isKyber then
        {
          mode = "postgres";
          connectionString = "postgres://postgres:postgres@localhost:5432/paperclip";
        }
      else
        {
          mode = "embedded-postgres";
        };
    server = {
      host = if host.isKyber then "0.0.0.0" else "127.0.0.1";
      port = 3100;
    };
  };

  configFile = pkgs.writeText "paperclip-config.json" configJson;

  setupScript = pkgs.replaceVars ./setup.sh {
    instance_dir = instanceDir;
    config_file = "${configFile}";
    cp = "${pkgs.coreutils}/bin/cp";
    is_kyber = if host.isKyber then "true" else "false";
  };
in
{
  home.activation.paperclipConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${setupScript} || true
  '';
}
