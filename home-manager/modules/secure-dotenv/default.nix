{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  script = pkgs.writeShellScript "secure-dotenv" ''
    set -euo pipefail
    # Enforce 600 on all .env files under home directory
    ${pkgs.findutils}/bin/find "${homeDir}" \
      -maxdepth 4 \
      -name '.env' -o -name '.env.*' -o -name '*.env' \
      2>/dev/null | while IFS= read -r f; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then
        current=$(${pkgs.coreutils}/bin/stat -c '%a' "$f")
        if [ "$current" != "600" ]; then
          chmod 600 "$f"
        fi
      fi
    done
  '';
in
{
  home.activation.secureDotenv = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${script}
  '';
}
