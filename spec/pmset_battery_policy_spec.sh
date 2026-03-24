#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'nix-darwin/services/pmset-battery-policy/power-policy.sh'
SCRIPT="$PWD/nix-darwin/services/pmset-battery-policy/power-policy.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@pmsetBin@|/usr/bin/pmset|g' -e 's|@awkBin@|'\"$(command -v awk)\"'|g' -e 's|@highBatteryThreshold@|30|g' -e 's|@highBatterySleepMinutes@|300|g' -e 's|@lowBatterySleepMinutes@|30|g' '$SCRIPT' | bash -n"
The status should be success
End
End

setup_policy_script() {
  TEST_DIR=$(mktemp -d)
  PMSET_LOG="$TEST_DIR/pmset.log"
  PMSET_BIN="$TEST_DIR/pmset"
  PREPROCESSED_SCRIPT="$TEST_DIR/power-policy.sh"
  : >"$PMSET_LOG"

  cat >"$PMSET_BIN" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$PMSET_LOG"
if [ "$1" = "-g" ] && [ "$2" = "batt" ]; then
  printf "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t%s%%; discharging; 4:00 remaining present: true\n" "$BATTERY_PERCENTAGE"
fi
EOF
  chmod +x "$PMSET_BIN"

  sed \
    -e "s|@pmsetBin@|$PMSET_BIN|g" \
    -e "s|@awkBin@|$(command -v awk)|g" \
    -e 's|@highBatteryThreshold@|30|g' \
    -e 's|@highBatterySleepMinutes@|300|g' \
    -e 's|@lowBatterySleepMinutes@|30|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_policy_script() {
  rm -rf "$TEST_DIR"
}

Describe 'percentage-based policy'
Before 'setup_policy_script'
After 'cleanup_policy_script'

It 'extends battery sleep at or above the threshold'
When run bash -c ': >"'"$PMSET_LOG"'"; BATTERY_PERCENTAGE=35 PMSET_LOG="'"$PMSET_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && cat "'"$PMSET_LOG"'"'
The status should be success
The output should include '-c sleep 0'
The output should include '-c powernap 1'
The output should include '-b sleep 300'
The output should include '-b powernap 1'
End

It 'keeps the conservative battery sleep below the threshold'
When run bash -c ': >"'"$PMSET_LOG"'"; BATTERY_PERCENTAGE=12 PMSET_LOG="'"$PMSET_LOG"'" "'"$PREPROCESSED_SCRIPT"'" >/dev/null && cat "'"$PMSET_LOG"'"'
The status should be success
The output should include '-b sleep 30'
The output should include '-b powernap 0'
End
End

End
