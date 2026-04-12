#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/services/qmd/activate.sh'
SCRIPT="$PWD/home-manager/services/qmd/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'checks for existing wiki collection'
When run bash -c "grep 'collection list' '$SCRIPT'"
The output should include 'collection list'
End

It 'adds wiki collection when missing'
When run bash -c "grep 'collection add' '$SCRIPT'"
The output should include 'collection add'
End
End

Describe 'home-manager/services/qmd/default.nix'
It 'enables on kyber and galactica only'
When run bash -c "grep 'isKyber || isGalactica' '$PWD/home-manager/services/qmd/default.nix'"
The output should include 'isKyber || isGalactica'
End

It 'runs qmd mcp --http'
When run bash -c "grep 'mcp' '$PWD/home-manager/services/qmd/default.nix'"
The output should include '"mcp"'
End

It 'quotes the activate script arguments'
When run cat "$PWD/home-manager/services/qmd/default.nix"
The output should include '"${./activate.sh}" "${qmdBin}" "${wikiDir}"'
End
End
