#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

Describe 'scripts/llm-update.sh'
SCRIPT="$PWD/scripts/llm-update.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'models.json dependency'
It 'references models.json'
When run bash -c "grep 'models.json' '$SCRIPT'"
The output should include 'models.json'
End

It 'exits if models.json is missing'
When run bash -c "grep 'models.json not found' '$SCRIPT'"
The output should include 'ERROR'
End
End

Describe 'template processing'
It 'uses sed for substitution'
When run bash -c "grep 'sed' '$SCRIPT'"
The output should include 'sed'
End

It 'defines template-to-output mappings'
When run bash -c "grep 'TEMPLATES' '$SCRIPT'"
The output should include 'TEMPLATES'
End

It 'processes .tpl. template files'
When run bash -c "grep '\.tpl\.' '$SCRIPT'"
The output should include '.tpl.'
End
End

Describe 'mapping coverage'
It 'includes aichat config in template mappings'
When run bash -c "grep 'config/aichat/config.tpl.yaml' '$SCRIPT'"
The output should include 'config/aichat/config.tpl.yaml'
End

It 'includes pi settings in template mappings'
When run bash -c "grep 'config/pi/settings.tpl.json' '$SCRIPT'"
The output should include 'config/pi/settings.tpl.json'
End

It 'includes llm default model in template mappings'
When run bash -c "grep 'config/llm/default_model.tpl.txt' '$SCRIPT'"
The output should include 'config/llm/default_model.tpl.txt'
End

It 'includes fish wrapper templates in template mappings'
When run bash -c "grep '_ocxe_function.tpl.fish' '$SCRIPT' && grep '_pixe_function.tpl.fish' '$SCRIPT' && grep '_pixel_function.tpl.fish' '$SCRIPT'"
The output should include '_ocxe_function.tpl.fish'
The output should include '_pixe_function.tpl.fish'
The output should include '_pixel_function.tpl.fish'
End
End

Describe 'jq pretty-printing'
It 'defines a jq pretty function for model names'
When run bash -c "grep 'def pretty' '$SCRIPT'"
The output should include 'def pretty'
End

It 'capitalizes Claude model names'
When run bash -c "grep 'Claude' '$SCRIPT'"
The output should include 'Claude'
End
End

Describe 'placeholder generation'
It 'converts keys to uppercase placeholders'
When run bash -c "grep 'placeholder=' '$SCRIPT'"
The output should include '__'
End

It 'generates PRETTY variant placeholders'
When run bash -c "grep '_PRETTY__' '$SCRIPT'"
The output should include '_PRETTY__'
End

It 'generates NONDOT variant placeholders'
When run bash -c "grep '_NONDOT__' '$SCRIPT'"
The output should include '_NONDOT__'
End
End

End
