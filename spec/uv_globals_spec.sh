#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'uv-globals/install-uv-globals.sh'
SCRIPT="$PWD/home-manager/modules/uv-globals/install-uv-globals.sh"

Describe 'systemd activation skip'
It 'checks systemctl is-system-running to detect boot'
When run bash -c "grep 'is-system-running' '$SCRIPT'"
The output should include 'is-system-running'
End

It 'skips install during system boot'
When run bash -c "grep -A 1 'is-system-running' '$SCRIPT'"
The output should include 'skipping uv globals install'
End
End

Describe 'host tool exclusion'
setup_exclusion() {
  mock_bin_setup timeout uname
  UV_TEST_HOME="$(mktemp -d)"
  export UV_TEST_HOME
  mkdir -p "$UV_TEST_HOME/dotfiles" "$UV_TEST_HOME/.local/bin"
  : >"$UV_TEST_HOME/dotfiles/pyproject.toml"
  : >"$UV_TEST_HOME/.local/bin/python3-vllm"
  printf '#!/usr/bin/env bash\necho Linux\n' >"$MOCK_BIN/uname"
  cat >"$MOCK_BIN/tomlq" <<'EOF'
#!/usr/bin/env bash
case "$2" in
*requires-python*) echo '>=3.13' ;;
*dependency-groups*) printf '%s\n' 'ruff>=0.1.0' 'huggingface-hub[mcp]>=2.2.0' 'vllm>=0.32.0' 'vllm-mlx>=0.6.0' ;;
*'.gpu[]'*) printf '%s\n' huggingface-hub vllm ;;
*'.darwin[]'*) echo vllm-mlx ;;
esac
EOF
  cat >"$MOCK_BIN/uv" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "uv $*" >>"$MOCK_LOG"
if [ "$1 $2" = "tool list" ]; then
  printf '%s\n' 'ruff v0.1.0' '- ruff' 'vllm v0.32.0' '- vllm' 'vllm-mlx v0.6.0' '- vllm-mlx'
fi
EOF
  chmod +x "$MOCK_BIN/tomlq" "$MOCK_BIN/uv"
}
cleanup_exclusion() {
  mock_bin_cleanup
  rm -rf "$UV_TEST_HOME"
  unset UV_TEST_HOME
}
Before 'setup_exclusion'
After 'cleanup_exclusion'

It 'uninstalls GPU and MLX tools on CPU-only Linux instead of installing them'
When run env HOME="$UV_TEST_HOME" UV_GLOBALS_GPU=0 bash "$SCRIPT"
The status should be success
The output should include 'Uninstalling vllm (excluded on this host)'
The contents of file "$MOCK_LOG" should include 'uv tool uninstall vllm'
The contents of file "$MOCK_LOG" should include 'uv tool uninstall vllm-mlx'
The contents of file "$MOCK_LOG" should not include 'uninstall huggingface-hub'
The contents of file "$MOCK_LOG" should not include 'uv tool install vllm'
The contents of file "$MOCK_LOG" should not include 'uv tool install huggingface-hub'
The path "$UV_TEST_HOME/.local/bin/python3-vllm" should not be exist
End

It 'keeps GPU tools on GPU Linux hosts and still drops MLX'
When run env HOME="$UV_TEST_HOME" UV_GLOBALS_GPU=1 bash "$SCRIPT"
The status should be success
The output should include 'vllm 0.32.0 already installed, skipping'
The contents of file "$MOCK_LOG" should include 'uv tool install huggingface-hub[mcp]>=2.2.0'
The contents of file "$MOCK_LOG" should include 'uv tool uninstall vllm-mlx'
The output should not include 'Uninstalling vllm ('
End

It 'keeps MLX tools on macOS'
printf '#!/usr/bin/env bash\necho Darwin\n' >"$MOCK_BIN/uname"
When run env HOME="$UV_TEST_HOME" UV_GLOBALS_GPU=1 bash "$SCRIPT"
The status should be success
The output should include 'vllm-mlx 0.6.0 already installed, skipping'
The contents of file "$MOCK_LOG" should not include 'uninstall'
End
End

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

Describe 'configuration'
It 'reads from dotfiles/pyproject.toml'
When run bash -c "grep 'PYPROJECT=' '$SCRIPT'"
The output should include 'dotfiles/pyproject.toml'
End
End

Describe 'tool checks'
It 'checks for uv command'
When run bash -c "grep 'command -v uv' '$SCRIPT'"
The output should include 'uv'
End

It 'checks for tomlq command'
When run bash -c "grep 'command -v tomlq' '$SCRIPT'"
The output should include 'tomlq'
End
End

Describe 'file handling'
It 'exits gracefully when pyproject.toml is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'offline skip'
It 'checks network connectivity before installing'
When run bash -c "grep 'timeout 3 bash' '$SCRIPT'"
The output should include 'timeout 3 bash'
End

It 'exits gracefully when offline'
When run bash -c "grep -A 2 'Network unavailable' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'tool installation'
It 'uses tomlq to parse TOML'
When run bash -c "grep 'tomlq' '$SCRIPT'"
The output should include 'tomlq'
End

It 'uses uv tool install'
When run bash -c "grep 'uv tool install' '$SCRIPT'"
The output should include 'uv tool install'
End

It 'uses --force flag for reinstall'
When run bash -c "grep -- '--force' '$SCRIPT'"
The output should include '--force'
End

It 'checks uv tool list for installed packages'
When run bash -c "grep 'uv tool list' '$SCRIPT'"
The output should include 'uv tool list'
End

It 'extracts package name from version spec'
When run bash -c "grep '><=!' '$SCRIPT'"
The output should include '><=!'
End

It 'extracts requested version from >= spec'
When run bash -c "grep 'req_version' '$SCRIPT'"
The output should include 'req_version'
End

It 'extracts installed version from uv tool list output'
When run bash -c "grep 'installed_version' '$SCRIPT'"
The output should include 'installed_version'
End

It 'skips install when version matches'
When run bash -c "grep 'already installed, skipping' '$SCRIPT'"
The output should include 'already installed, skipping'
End

It 'uses sort -V for version comparison instead of exact match'
When run bash -c "grep 'sort -V' '$SCRIPT'"
The output should include 'sort -V'
End

It 'skips when installed version is newer than required'
# Simulate: installed=0.15.9, required=0.15.8 -> should skip
When run bash -c "printf '0.15.8\n0.15.9\n' | sort -V | head -n1"
The output should eq '0.15.8'
End

It 'skips when installed version equals required'
# Simulate: installed=0.86.2, required=0.86.2 -> should skip
When run bash -c "printf '0.86.2\n0.86.2\n' | sort -V | head -n1"
The output should eq '0.86.2'
End

It 'detects when installed version is older than required'
# Simulate: installed=2.6.9, required=2.7.0 -> min is 2.6.9, not 2.7.0
When run bash -c "printf '2.7.0\n2.6.9\n' | sort -V | head -n1"
The output should eq '2.6.9'
End

It 'parses dependency-groups.tools'
When run bash -c "grep 'dependency-groups' '$SCRIPT'"
The output should include 'dependency-groups'
End

It 'parses requires-python version'
When run bash -c "grep 'requires-python' '$SCRIPT'"
The output should include 'requires-python'
End

It 'passes --python flag to uv tool install'
When run bash -c "grep -- '--python' '$SCRIPT'"
The output should include '--python'
End
End
End
