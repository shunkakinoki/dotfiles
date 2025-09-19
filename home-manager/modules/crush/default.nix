{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.file.".config/crush/crush.json".text = ''
    {
      "$schema": "https://charm.land/crush.json",
      "options": {
        "attribution": {
          "co_authored_by": false,
          "generated_with": true
        }
      },
      "lsp": {
        "nix": {
          "command": "nil"
        }
      }
    }
  '';
}
