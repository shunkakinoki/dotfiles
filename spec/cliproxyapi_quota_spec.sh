#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi/quota.sh'
SCRIPT="$PWD/home-manager/services/cliproxyapi/scripts/quota.sh"

setup_quota() {
  TEMP_QUOTA=$(mktemp -d)
  mkdir -p "$TEMP_QUOTA/bin" "$TEMP_QUOTA/dotfiles"
  printf '%s\n' 'CLIPROXY_MANAGEMENT_PASSWORD=test-management-key' 'OPENROUTER_API_KEY=test-openrouter-key' \
    >"$TEMP_QUOTA/dotfiles/.env"
  printf '%s\n' '[
    {"provider":"ollama-cloud","key_index":1,"host":"kamino1","port":1081},
    {"credential":"codex-mapped.json","host":"kamino2","port":1082}
  ]' >"$TEMP_QUOTA/kamino-tunnels.json"
  sed -e "s|@jq@|jq|g" \
    -e "s|@curl@|$TEMP_QUOTA/bin/curl|g" \
    -e "s|@mapping@|$TEMP_QUOTA/kamino-tunnels.json|g" \
    -e "s|@management_url@|http://kyber.test/v0/management|g" \
    "$SCRIPT" >"$TEMP_QUOTA/quota.sh"

  # Fake curl: logs every request (argv, then body) and answers from fixtures.
  cat >"$TEMP_QUOTA/bin/curl" <<'STUB'
#!/usr/bin/env bash
url="" body=""
for arg in "$@"; do
  case "$arg" in
  http*) url="$arg" ;;
  @-) body="$(cat)" ;;
  esac
done
printf 'ARGV %s\n' "$*" >>"$CURL_LOG"
[ -z "$body" ] || printf 'BODY %s\n' "$body" >>"$CURL_LOG"
case "$url" in
*/auth-files)
  cat <<'JSON'
{"files":[
  {"name":"codex-mapped.json","auth_index":"a1","provider":"codex","status":"active","disabled":false,
   "id_token":{"chatgpt_account_id":"acct-1","plan_type":"pro"}},
  {"name":"claude-direct.json","auth_index":"b2","provider":"claude","status":"active","disabled":false,
   "next_retry_after":"2000-01-01T00:00:00.5Z"},
  {"name":"gemini-other.json","auth_index":"c3","provider":"gemini","status":"active","disabled":false},
  {"name":"codex-off.json","auth_index":"d4","provider":"codex","status":"disabled","disabled":true}
]}
JSON
  ;;
*/api-call)
  if [ -n "${FAKE_TUNNEL_DOWN:-}" ] && jq -e 'has("proxy_url")' <<<"$body" >/dev/null; then
    echo '{"error":"request failed"}'
    exit 22
  fi
  case "$(jq -r .url <<<"$body")" in
  */wham/usage)
    jq -nc '{status_code: 200, body: ({plan_type: "pro",
      rate_limit: {limit_reached: true,
        primary_window: {used_percent: 41.6, limit_window_seconds: 604800, reset_after_seconds: 190800},
        secondary_window: {used_percent: 100, limit_window_seconds: 18000, reset_after_seconds: 5400}},
      credits: {has_credits: true, unlimited: false, balance: "12.50"},
      rate_limit_reset_credits: {available_count: 2}} | tojson)}'
    ;;
  */oauth/usage)
    jq -nc '{status_code: 200, body: ({five_hour: {utilization: 12, resets_at: "2000-01-01T00:00:00.123+00:00"},
      seven_day: {utilization: 55.4, resets_at: null},
      extra_usage: {is_enabled: true, used_credits: 300, monthly_limit: 5000}} | tojson)}'
    ;;
  */rate-limit-reset-credits/consume) echo '{"status_code":200,"body":"{}"}' ;;
  */rate-limit-reset-credits)
    if [ -n "${FAKE_CREDITS_STATUS:-}" ]; then
      jq -nc --argjson code "$FAKE_CREDITS_STATUS" '{status_code: $code, body: "{}"}'
      exit 0
    fi
    jq -nc '{status_code: 200, body: ({available_count: 2, credits: [
      {id: "late", reset_type: "codex_rate_limits", status: "available",
       granted_at: "2099-01-01T00:00:00Z", expires_at: "2099-02-01T00:00:00.5Z"},
      {id: "early", reset_type: "codex_rate_limits", status: "available",
       granted_at: "2098-12-15T00:00:00Z", expires_at: "2099-01-15T00:00:00Z"},
      {id: "spent", reset_type: "codex_rate_limits", status: "redeemed",
       granted_at: "2098-12-01T00:00:00Z", expires_at: "2099-01-02T00:00:00Z"},
      {id: "other", reset_type: "something_else", status: "available",
       granted_at: "2098-12-01T00:00:00Z", expires_at: "2099-01-03T00:00:00Z"}]} | tojson)}'
    ;;
  *) echo '{"status_code":404,"body":""}' ;;
  esac
  ;;
*/reset-quota) echo '{"status":"ok"}' ;;
*/credits) echo '{"data":{"total_credits":20,"total_usage":7.5}}' ;;
*) exit 7 ;;
esac
STUB
  chmod +x "$TEMP_QUOTA/bin/curl"
  export CURL_LOG="$TEMP_QUOTA/curl.log"
  : >"$CURL_LOG"
}

cleanup_quota() {
  rm -rf "$TEMP_QUOTA"
}

Before 'setup_quota'
After 'cleanup_quota'

quota() {
  HOME="$TEMP_QUOTA" bash "$TEMP_QUOTA/quota.sh" "$@"
}

api_call_body() {
  jq -c --arg url "$1" 'select(.url == $url)' < <(sed -n 's/^BODY //p' "$CURL_LOG")
}

codex_usage_call() { api_call_body 'https://chatgpt.com/backend-api/wham/usage'; }
claude_usage_call() { api_call_body 'https://api.anthropic.com/api/oauth/usage'; }
redeem_call() { api_call_body 'https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume'; }
wham_usage_calls() { codex_usage_call | wc -l | tr -d ' '; }
reset_credits_call() { api_call_body 'https://chatgpt.com/backend-api/wham/rate-limit-reset-credits'; }

Describe 'status'
It 'reports usage windows, resets, credits, and cooldowns for every account'
When call quota
The status should be success
The output should include 'CREDENTIAL'
The output should match pattern '*codex-mapped.json*kamino2*pro*100% 1h30m*42% 2d5h*bal 12.50*2*active, limit reached*'
The output should match pattern '*claude-direct.json*direct*12% now*55% ?*extra 300/5000*active, cooldown now*'
The output should match pattern '*gemini-other.json*direct*-*active*'
The output should match pattern '*codex-off.json*disabled*'
The output should match pattern '*openrouter (api key)*direct*$12.5 left*'
End

It 'routes a tunnel-mapped credential through its kamino SOCKS tunnel'
When call quota
The output should include 'codex-mapped.json'
The result of function codex_usage_call should include '"proxy_url":"socks5://127.0.0.1:1082"'
The result of function codex_usage_call should include '"Chatgpt-Account-Id":"acct-1"'
The result of function codex_usage_call should include '"Authorization":"Bearer $TOKEN$"'
End

It 'sends unmapped credentials without a proxy override'
When call quota
The output should include 'claude-direct.json'
The result of function claude_usage_call should not include 'proxy_url'
The result of function claude_usage_call should include '"anthropic-beta":"oauth-2025-04-20"'
End

It 'skips upstream calls for disabled and non-usage providers'
When call quota
The output should include 'gemini-other.json'
The contents of file "$CURL_LOG" should not include '"auth_index":"c3"'
The contents of file "$CURL_LOG" should not include '"auth_index":"d4"'
End

It 'reports a down tunnel as an error instead of falling back to direct'
export FAKE_TUNNEL_DOWN=1
When call quota
The status should be success
The output should match pattern '*codex-mapped.json*kamino2*error: {"error":"request failed"}*'
The output should match pattern '*claude-direct.json*12% now*'
The result of function wham_usage_calls should equal 1
The result of function codex_usage_call should include '"proxy_url":"socks5://127.0.0.1:1082"'
End

It 'never puts keys on the curl command line'
When call quota
The output should include 'CREDENTIAL'
The contents of file "$CURL_LOG" should not include 'test-management-key'
The contents of file "$CURL_LOG" should not include 'test-openrouter-key'
End

It 'emits raw records with --json and narrows by filter'
When call quota status --json claude
The status should be success
The output should include '"name": "claude-direct.json"'
The output should not include 'codex-mapped.json'
The output should include '"openrouter": null'
End

It 'fails without a management key'
When run bash -c 'printf "" >"$1/dotfiles/.env" && HOME="$1" CLIPROXY_MANAGEMENT_PASSWORD= bash "$1/quota.sh"' _ "$TEMP_QUOTA"
The status should be failure
The stderr should include 'CLIPROXY_MANAGEMENT_PASSWORD is not set'
End
End

Describe 'resets'
It 'lists window resets and reset-credit expiries, soonest first'
When call quota resets
The status should be success
The line 1 of output should match pattern 'CREDENTIAL*TUNNEL*RESET*IN*AT (UTC)*DETAIL'
The line 2 of output should match pattern 'claude-direct.json*direct*5h window resets*now*2000-01-01T00:00:00Z*12% used'
The line 3 of output should match pattern 'codex-mapped.json*kamino2*5h window resets*1h*100% used'
The line 4 of output should match pattern 'codex-mapped.json*kamino2*week window resets*2d*42% used'
The line 5 of output should match pattern 'codex-mapped.json*kamino2*reset credit expires*2099-01-15T00:00:00Z*granted 2098-12-15'
The line 6 of output should match pattern 'codex-mapped.json*kamino2*reset credit expires*2099-02-01T00:00:00Z*granted 2099-01-01'
The lines of output should equal 6
End

It 'fetches reset credits through the credential tunnel'
When call quota resets
The output should include 'reset credit expires'
The result of function reset_credits_call should include '"proxy_url":"socks5://127.0.0.1:1082"'
The result of function reset_credits_call should include '"Originator":"Codex Desktop"'
End

It 'emits sorted rows with --json and narrows by filter'
When call quota resets --json codex
The status should be success
The output should include '"what": "reset credit expires"'
The output should not include 'claude-direct.json'
End

It 'reports a failed reset-credit lookup instead of dropping it'
export FAKE_CREDITS_STATUS=429
When call quota resets
The status should be success
The output should match pattern '*codex-mapped.json*kamino2*error*-*-*reset credits HTTP 429*'
The output should include 'week window resets'
The output should not include 'reset credit expires'
End

It 'reports a down tunnel as an error row'
export FAKE_TUNNEL_DOWN=1
When call quota resets
The status should be success
The output should match pattern '*codex-mapped.json*kamino2*error*-*-*usage {"error":"request failed"}*'
The output should include 'claude-direct.json'
End
End

Describe 'reset'
It 'clears the local cooldown for every enabled credential'
When call quota reset all
The status should be success
The line 1 of output should equal 'codex-mapped.json: local cooldown cleared'
The line 2 of output should equal 'claude-direct.json: local cooldown cleared'
The output should not include 'codex-off.json'
The contents of file "$CURL_LOG" should include 'BODY {"auth_index":"b2"}'
End

It 'fails when nothing matches'
When call quota reset nope
The status should be failure
The stderr should include "no credential matches 'nope'"
End
End

Describe 'redeem'
It 'requires --yes before spending a reset credit'
When call quota redeem codex-mapped.json
The status should be failure
The stderr should include 'pass --yes'
The contents of file "$CURL_LOG" should equal ''
End

It 'spends one reset credit through the tunnel, then clears the cooldown'
When call quota redeem codex-mapped --yes
The status should be success
The line 1 of output should equal 'codex-mapped.json: redeemed one rate-limit reset credit via kamino2'
The line 2 of output should equal 'codex-mapped.json: local cooldown cleared'
The result of function redeem_call should include '"proxy_url":"socks5://127.0.0.1:1082"'
The result of function redeem_call should include 'redeem_request_id'
End

It 'refuses an ambiguous selector'
When call quota redeem codex --yes
The status should be failure
The stderr should include 'matches more than one credential'
End

It 'refuses non-codex credentials'
When call quota redeem claude-direct.json --yes
The status should be failure
The stderr should include 'only applies to codex credentials'
End
End
End
