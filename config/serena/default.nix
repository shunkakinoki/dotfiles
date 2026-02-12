{ config, ... }:
let
  serenaConfigSrc = ./serena_config.yml;
  serenaConfigDest = "${config.home.homeDirectory}/.serena/serena_config.yml";
in
{
  home.activation.serenaConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$(dirname "${serenaConfigDest}")"
    if [ ! -f "${serenaConfigDest}" ] || [ -L "${serenaConfigDest}" ]; then
      rm -f "${serenaConfigDest}"
      cp "${serenaConfigSrc}" "${serenaConfigDest}"
      chmod u+w "${serenaConfigDest}"
    fi
  '';
}
