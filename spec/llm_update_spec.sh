#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034,SC2016

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

It 'checks for jq before generating outputs'
When run bash -c "grep 'require_command jq' '$SCRIPT'"
The output should include 'require_command jq'
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

Describe 'generated fish wrapper outputs'
Parameters:dynamic
for file in $(git ls-files 'home-manager/programs/fish/functions/*.tpl.fish'); do
  output_file=${file/.tpl/}
  %data "$file" "$output_file"
done
End

It 'has a generated fish wrapper sibling: $2'
The path "$2" should be exist
End

It 'keeps generated fish wrappers non-empty: $2'
When run bash -c "[ -s '$2' ]"
The status should be success
End

It 'resolves placeholders in generated fish wrappers: $2'
When run bash -c "! grep -Eq '__[A-Z0-9_]+__' '$2'"
The status should be success
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

Describe 'failure handling'
setup_failure_fixture() {
  TEMP_ROOT=$(mktemp -d)
  MOCK_BIN=$(mktemp -d)
  TARGET="$TEMP_ROOT/home-manager/programs/fish/functions/_pixelh_function.fish"

  mkdir -p "$TEMP_ROOT/scripts" "$(dirname "$TARGET")"
  cp -f "$SCRIPT" "$TEMP_ROOT/scripts/llm-update.sh"
  cp -f "$PWD/models.json" "$TEMP_ROOT/models.json"
  cp -f "$PWD/home-manager/programs/fish/functions/_pixelh_function.tpl.fish" "$TEMP_ROOT/home-manager/programs/fish/functions/_pixelh_function.tpl.fish"
  printf 'sentinel\n' >"$TARGET"

  cat >"$MOCK_BIN/jq" <<'EOF'
#!/usr/bin/env bash
echo "mock jq failure" >&2
exit 127
EOF
  chmod +x "$MOCK_BIN/jq"

  REAL_BIN_DIRS=$(
    for cmd in bash dirname mktemp mv sed tr awk paste; do
      dirname "$(command -v "$cmd")"
    done | awk '!seen[$0]++ { printf "%s%s", sep, $0; sep=":" }'
  )
}

cleanup_failure_fixture() {
  rm -rf "$TEMP_ROOT" "$MOCK_BIN"
}

Before 'setup_failure_fixture'
After 'cleanup_failure_fixture'

It 'fails fast when jq is unavailable'
When run bash -c "PATH='$MOCK_BIN:$REAL_BIN_DIRS' bash '$TEMP_ROOT/scripts/llm-update.sh' >/dev/null 2>&1"
The status should not be success
End

It 'preserves generated outputs when jq is unavailable'
When run bash -c "PATH='$MOCK_BIN:$REAL_BIN_DIRS' bash '$TEMP_ROOT/scripts/llm-update.sh' >/dev/null 2>&1 || true; cat '$TARGET'"
The output should equal 'sentinel'
End
End

End
