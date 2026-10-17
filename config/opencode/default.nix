{
  config,
  pkgs,
  ...
}:
let
  jq = "${pkgs.jq}/bin/jq";
  serviceEnv = pkgs.writeShellScript "opencode-service-env" ''
    set -euo pipefail
    svc="$HOME/.config/opencode/service.json"
    mkdir -p "$(dirname "$svc")"
    umask 077
    if [ ! -f "$svc" ]; then
      ${jq} -n '{env: {OPENCODE_DB: "opencode-v2.db"}}' > "$svc"
    elif [ "$(${jq} -r '.env.OPENCODE_DB // empty' "$svc")" != "opencode-v2.db" ]; then
      tmp="$(mktemp "$svc.XXXXXX")"
      ${jq} '.env.OPENCODE_DB = "opencode-v2.db"' "$svc" > "$tmp"
      mv "$tmp" "$svc"
    fi
  '';
in
{
  # Keeps v2 off the 1.x opencode.db so 1.x history is never read or rewritten.
  home.sessionVariables.OPENCODE_DB = "opencode-v2.db";

  # The v2 service takes its env from service.json, not the spawning shell.
  # The service also writes its client password there, so merge instead of
  # linking a read-only file; `opencode service set env` would restart it.
  home.activation.opencodeServiceEnv = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${serviceEnv}
  '';

  home.file.".config/opencode/opencode.jsonc" = {
    source = ./opencode.jsonc;
  };

  home.file.".config/opencode/opencode-fallback.jsonc" = {
    source = ./opencode-fallback.jsonc;
  };

  # OpenCode reports lowercase bash; Claude's Bash matcher is case-sensitive.
  home.file.".config/opencode/hooks.json" = {
    source = ./hooks.json;
  };

  home.file.".config/opencode/tui.json" = {
    source = ./tui.json;
  };

  home.file.".config/opencode/themes/transparent.json" = {
    source = ./themes/transparent.json;
  };

  home.file.".config/opencode/plugins/moshi-hooks.ts" = {
    source = ../../generated/hooks/moshi/opencode/moshi-hooks.ts;
  };

  home.file.".config/opencode/plugins/claude-hooks.ts" = {
    source = ./plugins/claude-hooks.ts;
  };
}
