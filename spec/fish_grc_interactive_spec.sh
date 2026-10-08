#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'fish grc wrapping is interactive-only'
FISH_NIX="$PWD/home-manager/programs/fish/default.nix"

It 'does not load grc as a Home Manager plugin, which would run in every shell'
When run grep -F 'pkgs.fishPlugins.grc) src' "$FISH_NIX"
The status should be failure
End

It 'loads grc only inside interactiveShellInit'
When run awk '/interactiveShellInit = /{i=NR} /^    [a-zA-Z]+ = /{if (NR != i) i=0} /grc\.src}\/conf\.d\/grc\.fish/{n++; if (i) ok++} END{ print (n == 1 && ok == 1) ? "ok" : "bad n=" n " ok=" ok }' "$FISH_NIX"
The output should equal 'ok'
End

It 'adds the grc functions directory for grc.wrap'
When run grep -F 'set -a fish_function_path ${pkgs.fishPlugins.grc.src}/functions' "$FISH_NIX"
The status should be success
The output should include 'grc.src}/functions'
End
End
