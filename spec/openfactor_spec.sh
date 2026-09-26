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

It 'skips cleanly when the published CLI cannot be installed'
TMP_HOME="$(mktemp -d)"
When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" OPENFACTOR_RELEASE_ROOT="file://$TMP_HOME/missing" "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The error should include 'OpenFactor CLI install failed; skipping orchestration hook registration'
End

It 'installs the published CLI for the openfactor tenant before registering hooks'
TMP_HOME="$(mktemp -d)"
RELEASES="$TMP_HOME/releases"
mkdir -p "$RELEASES"
cat >"$RELEASES/install.sh" <<'SH'
#!/bin/sh
printf 'tenant=%s root=%s\n' "$1" "$CLI_RELEASE_ROOT" >&2
mkdir -p "$CLI_INSTALL_DIR"
printf '#!/bin/sh\nprintf "%%s\\n" "$*"\n' >"$CLI_INSTALL_DIR/$1"
chmod +x "$CLI_INSTALL_DIR/$1"
SH

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" OPENFACTOR_RELEASE_ROOT="file://$RELEASES" "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The output should equal 'hooks install --scope host --json'
The error should include "tenant=openfactor root=file://$RELEASES"
The path "$TMP_HOME/.local/bin/openfactor" should be executable
End

It 'upgrades the managed CLI through its own release channel'
TMP_HOME="$(mktemp -d)"
TMP_BIN="$TMP_HOME/.local/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/openfactor" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*"
SH
chmod +x "$TMP_BIN/openfactor"

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" "$BASH_BIN" -c 'PATH="$2:/usr/bin:/bin" "$1"' _ "$SCRIPT" "$BASH_DIR"
The status should be success
The output should equal 'hooks install --scope host --json'
The error should equal 'upgrade'
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

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" "$BASH_BIN" -c 'PATH="$1:$3" "$2"' _ "$TMP_BIN" "$SCRIPT" "$BASH_DIR"
The output should equal 'hooks install --scope host --json'
The status should be success
End

It 'warns and continues when the CLI cannot register hooks'
TMP_HOME="$(mktemp -d)"
TMP_BIN="$TMP_HOME/bin"
mkdir -p "$TMP_BIN"
cat >"$TMP_BIN/openfactor" <<'SH'
#!/usr/bin/env bash
echo 'Unknown command: hooks install' >&2
exit 2
SH
chmod +x "$TMP_BIN/openfactor"

When run env -u OPENFACTOR_BIN HOME="$TMP_HOME" "$BASH_BIN" -c 'PATH="$1:$3" "$2"' _ "$TMP_BIN" "$SCRIPT" "$BASH_DIR"
The status should be success
The error should include 'OpenFactor hook registration failed; continuing activation'
End

It 'hands the pi extension payload over as a file instead of a pipe'
TMP_HOME="$(mktemp -d)"
EXT="$TMP_HOME/.pi/agent/extensions/openfactor-hooks.ts"
mkdir -p "$(dirname "$EXT")"
cat >"$EXT" <<'TS'
import { spawn } from "node:child_process";

function send(event: string, payload: unknown): void {
  try {
    const child = spawn(client, ["pi-hook", event], { stdio: ["pipe", "ignore", "ignore"] });
    child.stdin.end(JSON.stringify(payload ?? {}));
  } catch {}
}
TS

When run env HOME="$TMP_HOME" OPENFACTOR_BIN=/usr/bin/true "$BASH_BIN" "$SCRIPT"
The status should be success
The contents of file "$EXT" should include 'stdio: [fd, "ignore", "ignore"], detached: true'
The contents of file "$EXT" should include 'import { closeSync, openSync, unlinkSync, writeFileSync } from "node:fs";'
The contents of file "$EXT" should not include '"pipe"'
End

It 'warns and continues when OPENFACTOR_BIN is not executable'
TMP_HOME="$(mktemp -d)"
When run env HOME="$TMP_HOME" OPENFACTOR_BIN="$TMP_HOME/missing" "$BASH_BIN" "$SCRIPT"
The status should be success
The error should include 'OpenFactor CLI is not executable'
End
End
