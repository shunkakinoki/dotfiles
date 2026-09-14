# Build-time merge of a hand-maintained agent config with its generated Moshi
# hook fragment, so activation scripts keep receiving one complete document.
{ pkgs }:
name: base: fragment:
pkgs.runCommand name { } ''
  ${pkgs.bash}/bin/bash ${./merge-moshi-hooks.sh} ${base} ${fragment} ${pkgs.jq}/bin/jq >"$out"
''
