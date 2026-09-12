#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'config/openfactor/install.sh'
SCRIPT="$PWD/config/openfactor/install.sh"
BASH_BIN="$(command -v bash)"
BASH_DIR="$(dirname "$BASH_BIN")"

It 'uses the OpenFactor CLI as the single host hook installer'
When run head -1 "$SCRIPT"
The output should equal '#!/usr/bin/env bash'
End

It 'skips cleanly when the CLI is not installed'
When run "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The error should include 'OpenFactor CLI not found; skipping orchestration hook registration'
End

It 'delegates host registration to the CLI'
TMP_HOME="$(mktemp -d)"
TMP_BIN="$TMP_HOME/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/openfactor" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*"
SH
chmod +x "$TMP_BIN/openfactor"

When run "$BASH_BIN" -c 'PATH="$1:$3" "$2"' _ "$TMP_BIN" "$SCRIPT" "$BASH_DIR"
The output should equal 'hooks install --scope host --json'
The status should be success
End
End
