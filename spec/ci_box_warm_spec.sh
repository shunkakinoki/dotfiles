#!/usr/bin/env bash

Describe 'CI box warm runner'

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/ghq/github.com/org/a-first" "$TEST_ROOT/home/ghq/github.com/org/b-second"
  jq_root=$(dirname "$(dirname "$(command -v jq)")")
  cat >"$TEST_ROOT/bin/find" <<'FIND'
#!/usr/bin/env bash
/usr/bin/find "$@" | sort -z
FIND
  chmod +x "$TEST_ROOT/bin/find"
  sed \
    -e "s#@jq@#$jq_root#g" \
    -e "s#@findutils@#$TEST_ROOT#g" \
    -e "s#@bunBin@#$TEST_ROOT/bin/bun#g" \
    "$PWD/home-manager/services/ci-box-warm/run.sh" >"$TEST_ROOT/run.sh"
  chmod +x "$TEST_ROOT/run.sh"
  cat >"$TEST_ROOT/bin/bun" <<'BUN'
#!/usr/bin/env bash
printf '%s|%s\n' "$PWD" "$*" >>"$BUN_LOG"
if [ "${FAIL_FIRST:-0}" = 1 ] && [ "$PWD" = "$HOME/ghq/github.com/org/a-first" ]; then
  exit 1
fi
if [ "${FAIL_ALL:-0}" = 1 ]; then
  exit 1
fi
exit 0
BUN
  chmod +x "$TEST_ROOT/bin/bun"
}

cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

It 'runs the first checkout that defines the command in scripts'
cat >"$TEST_ROOT/home/ghq/github.com/org/a-first/package.json" <<'JSON'
{"dependencies":{"note":"ci:box-warm"}}
JSON
cat >"$TEST_ROOT/home/ghq/github.com/org/b-second/package.json" <<'JSON'
{"scripts":{"ci:box-warm":"echo warm"}}
JSON
When run env HOME="$TEST_ROOT/home" BUN_LOG="$TEST_ROOT/bun.log" "$TEST_ROOT/run.sh"
The status should be success
The contents of file "$TEST_ROOT/bun.log" should include "$TEST_ROOT/home/ghq/github.com/org/b-second|run ci:box-warm"
End

It 'continues to the next matching checkout when an earlier run fails'
cat >"$TEST_ROOT/home/ghq/github.com/org/a-first/package.json" <<'JSON'
{"scripts":{"ci:box-warm":"echo first"}}
JSON
cat >"$TEST_ROOT/home/ghq/github.com/org/b-second/package.json" <<'JSON'
{"scripts":{"ci:box-warm":"echo second"}}
JSON
When run env HOME="$TEST_ROOT/home" BUN_LOG="$TEST_ROOT/bun.log" FAIL_FIRST=1 "$TEST_ROOT/run.sh"
The status should be success
The contents of file "$TEST_ROOT/bun.log" should include "$TEST_ROOT/home/ghq/github.com/org/a-first|run ci:box-warm"
The contents of file "$TEST_ROOT/bun.log" should include "$TEST_ROOT/home/ghq/github.com/org/b-second|run ci:box-warm"
End

It 'fails clearly when no checkout exposes the command'
When run env HOME="$TEST_ROOT/home" BUN_LOG="$TEST_ROOT/bun.log" "$TEST_ROOT/run.sh"
The status should be failure
The error should include 'could not find a ghq checkout exposing ci:box-warm'
End

It 'reports when every matching checkout fails'
cat >"$TEST_ROOT/home/ghq/github.com/org/a-first/package.json" <<'JSON'
{"scripts":{"ci:box-warm":"echo first"}}
JSON
cat >"$TEST_ROOT/home/ghq/github.com/org/b-second/package.json" <<'JSON'
{"scripts":{"ci:box-warm":"echo second"}}
JSON
When run env HOME="$TEST_ROOT/home" BUN_LOG="$TEST_ROOT/bun.log" FAIL_ALL=1 "$TEST_ROOT/run.sh"
The status should be failure
The error should include 'all ghq checkouts exposing ci:box-warm failed'
End
End
