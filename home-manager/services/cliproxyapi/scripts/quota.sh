#!/usr/bin/env bash
# Usage windows, reset times, and credits for every CLIProxyAPI account, read
# through the management API of the kyber server that holds the OAuth files.
# Upstream calls for a credential mapped in kamino-tunnels.json pass that
# credential's kamino SOCKS tunnel explicitly, so they fail rather than leave
# from another IP. The management API itself, local cooldown resets, API key
# credit lookups, and unmapped credentials connect directly.
# jq programs and the server-side $TOKEN$ placeholder stay single-quoted.
# shellcheck disable=SC2016
set -euo pipefail

JQ="@jq@"
CURL="@curl@"
MAPPING_FILE="@mapping@"
DEFAULT_MANAGEMENT_URL="@management_url@"

CODEX_USAGE_URL="https://chatgpt.com/backend-api/wham/usage"
CODEX_RESET_CREDITS_URL="https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
CODEX_REDEEM_URL="${CODEX_RESET_CREDITS_URL}/consume"
CODEX_USER_AGENT="codex-tui/0.149.1 (Mac OS 26.5.2; arm64) iTerm.app/3.6.11 (codex-tui; 0.149.1)"
CLAUDE_USAGE_URL="https://api.anthropic.com/api/oauth/usage"
OPENROUTER_CREDITS_URL="https://openrouter.ai/api/v1/credits"

usage() {
  cat <<'EOF'
Usage: cliproxy-quota [status] [--json] [filter]
       cliproxy-quota resets [--json] [filter]
       cliproxy-quota reset <credential|all>
       cliproxy-quota redeem <credential> --yes

  status  Usage windows, reset times, and credits for every account (default).
  resets  Upcoming window resets and Codex reset-credit expiries, soonest first.
  reset   Clear CLIProxyAPI's local quota cooldown so routing retries the account.
  redeem  Spend one Codex rate-limit reset credit upstream, then clear the cooldown.

A credential is an auth file name, an auth index, or a unique substring of the
name. CLIPROXY_QUOTA_URL overrides the management API base URL.
EOF
}

die() {
  echo "cliproxy-quota: $*" >&2
  exit 1
}

env_file="${HOME}/dotfiles/.env"
if [ -f "$env_file" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi

MANAGEMENT_URL="${CLIPROXY_QUOTA_URL:-$DEFAULT_MANAGEMENT_URL}"
MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_PASSWORD:-${CLIPROXY_MANAGEMENT_KEY:-}}"

# Keys go to curl through a config file descriptor, never through argv.
curl_bearer() {
  local token="${1//\\/\\\\}"
  token="${token//\"/\\\"}"
  printf 'header = "Authorization: Bearer %s"\n' "$token"
}

management() {
  local method="$1" path="$2" body="${3:-}" out
  if [ -n "$body" ]; then
    out="$(printf '%s' "$body" | "$CURL" -sS --fail-with-body --max-time 90 -X "$method" \
      --config <(curl_bearer "$MANAGEMENT_KEY") \
      -H 'Content-Type: application/json' --data-binary @- \
      "${MANAGEMENT_URL%/}${path}")" || {
      echo "cliproxy-quota: $method $path failed: ${out:-no response}" >&2
      return 1
    }
  else
    out="$("$CURL" -sS --fail-with-body --max-time 90 -X "$method" \
      --config <(curl_bearer "$MANAGEMENT_KEY") \
      "${MANAGEMENT_URL%/}${path}")" || {
      echo "cliproxy-quota: $method $path failed: ${out:-no response}" >&2
      return 1
    }
  fi
  printf '%s\n' "$out"
}

tunnel_proxy() {
  "$JQ" -r --arg name "$1" \
    'first(.[] | select(.credential == $name) | "socks5://127.0.0.1:\(.port)") // empty' \
    "$MAPPING_FILE"
}

tunnel_host() {
  "$JQ" -r --arg name "$1" \
    'first(.[] | select(.credential == $name) | .host) // "direct"' \
    "$MAPPING_FILE"
}

# The server substitutes $TOKEN$ with the credential's access token, so tokens
# never reach this shell. A mapped credential always names its tunnel.
api_call() {
  local auth_index="$1" name="$2" method="$3" url="$4" header="$5" data="${6:-}" proxy body
  proxy="$(tunnel_proxy "$name")"
  body="$("$JQ" -nc --arg index "$auth_index" --arg method "$method" --arg url "$url" \
    --argjson header "$header" --arg data "$data" --arg proxy "$proxy" \
    '{auth_index: $index, method: $method, url: $url, header: $header}
      + (if $data == "" then {} else {data: $data} end)
      + (if $proxy == "" then {} else {proxy_url: $proxy} end)')"
  management POST /api-call "$body"
}

codex_header() {
  "$JQ" -c --arg ua "$CODEX_USER_AGENT" \
    '{"Authorization": "Bearer $TOKEN$", "Content-Type": "application/json", "User-Agent": $ua}
      + (if .id_token.chatgpt_account_id then {"Chatgpt-Account-Id": .id_token.chatgpt_account_id} else {} end)' \
    <<<"$1"
}

CLAUDE_HEADER='{"Authorization":"Bearer $TOKEN$","Content-Type":"application/json","anthropic-beta":"oauth-2025-04-20"}'

account_record() {
  local file="$1" name provider index disabled tunnel url="" header="" response="" error=""
  name="$("$JQ" -r '.name' <<<"$file")"
  provider="$("$JQ" -r '.provider // .type // ""' <<<"$file")"
  index="$("$JQ" -r '.auth_index // ""' <<<"$file")"
  disabled="$("$JQ" -r '.disabled // false' <<<"$file")"
  tunnel="$(tunnel_host "$name")"

  case "$provider" in
  codex)
    url="$CODEX_USAGE_URL"
    header="$(codex_header "$file")"
    ;;
  claude)
    url="$CLAUDE_USAGE_URL"
    header="$CLAUDE_HEADER"
    ;;
  esac

  if [ -n "$url" ] && [ "$disabled" != "true" ] && [ -n "$index" ]; then
    if ! response="$(api_call "$index" "$name" GET "$url" "$header" 2>&1)"; then
      error="${response##*failed: }"
      response=""
    fi
  fi

  "$JQ" -nc --argjson file "$file" --arg tunnel "$tunnel" --arg response "$response" --arg error "$error" '
    ($response | if . == "" then null else (fromjson? // null) end) as $r
    | (($r.status_code // 0) >= 200 and ($r.status_code // 0) < 300) as $ok
    | {
        name: $file.name,
        provider: ($file.provider // $file.type),
        auth_index: $file.auth_index,
        tunnel: $tunnel,
        plan: $file.id_token.plan_type,
        status: $file.status,
        disabled: ($file.disabled // false),
        next_retry_after: $file.next_retry_after,
        usage: (if $ok then ($r.body | fromjson? // null) else null end),
        error: (if $error != "" then $error
          elif $r != null and ($ok | not) then "HTTP \($r.status_code)"
          else null end)
      }'
}

openrouter_record() {
  local out
  [ -n "${OPENROUTER_API_KEY:-}" ] || {
    echo null
    return
  }
  if out="$("$CURL" -sS --fail-with-body --max-time 30 \
    --config <(curl_bearer "$OPENROUTER_API_KEY") "$OPENROUTER_CREDITS_URL")"; then
    "$JQ" -c '{total_credits: .data.total_credits, total_usage: .data.total_usage}' <<<"$out"
  else
    "$JQ" -nc --arg error "${out:-request failed}" '{error: $error}'
  fi
}

JQ_LIB='
  def epoch: try (if type == "number" then .
    elif type == "string" then (sub("\\.[0-9]+"; "") | sub("(\\+00:00|Z)$"; "Z") | fromdateiso8601)
    else null end) catch null;
  def left: if . == null then "?"
    else (floor) as $s
    | if $s <= 0 then "now"
      elif $s < 3600 then "\($s / 60 | floor)m"
      elif $s < 86400 then "\($s / 3600 | floor)h\($s % 3600 / 60 | floor)m"
      else "\($s / 86400 | floor)d\($s % 86400 / 3600 | floor)h" end end;
  def pct: if . == null then "-" else "\(tonumber | round)%" end;
  def lws: (.limit_window_seconds // .limitWindowSeconds) | if . == null then null else tonumber end;
  def table: (transpose | map(map(tostring | length) | max)) as $w
    | .[] | [to_entries[] | (.value | tostring) as $s
      | $s + ([range(0; $w[.key] - ($s | length))] | map(" ") | join(""))]
    | join("  ") | sub(" +$"; "");
'

STATUS_TABLE='
  # Codex reports windows by length, not position: a plan can have only a
  # weekly primary window. Windows without a length fall back to position.
  def codex_pick($short): [.primary_window, .secondary_window] as $w
    | ([$w[] | select(. != null and lws != null and ((lws <= 86400) == $short))] | first)
      // (if $short then $w[0] else $w[1] end | if . != null and lws == null then . else null end);
  def codex_window: if . == null then "-"
    else "\((.used_percent // .usedPercent) | pct) \((.reset_after_seconds // .resetAfterSeconds
      // ((.reset_at // .resetAt) | epoch | if . == null then null else . - now end)) | left)" end;
  def claude_window: if . == null then "-"
    else "\(.utilization | pct) \(.resets_at | epoch | if . == null then null else . - now end | left)" end;
  def row:
    .usage as $u
    | (if .provider == "codex" then
        [($u.rate_limit | codex_pick(true) | codex_window),
         ($u.rate_limit | codex_pick(false) | codex_window),
         ($u.credits | if . == null then "-"
           elif .unlimited then "unlimited"
           elif .has_credits then "bal \(.balance)"
           else "none" end),
         ($u.rate_limit_reset_credits.available_count // "-" | tostring)]
      elif .provider == "claude" then
        [($u.five_hour | claude_window),
         ($u.seven_day | claude_window),
         ($u.extra_usage | if . != null and .is_enabled then "extra \(.used_credits)/\(.monthly_limit)" else "-" end),
         "-"]
      else ["-", "-", "-", "-"] end) as $cols
    | (if .disabled then "disabled"
       elif .error != null then "error: \(.error)"
       else [(.status // "-"),
             (if $u.rate_limit.limit_reached then "limit reached" else empty end),
             (.next_retry_after | epoch | if . == null then empty else "cooldown \(. - now | left)" end)]
            | join(", ") end) as $state
    | [.name, .tunnel, ($u.plan_type // .plan // "-"), $cols[0], $cols[1], $cols[2], $cols[3], $state];
  def table_rows:
  [["CREDENTIAL", "TUNNEL", "PLAN", "5H", "WEEK", "CREDITS", "RESETS", "STATE"]]
  + [.accounts[] | row]
  + (if .openrouter == null then []
     elif .openrouter.error != null then [["openrouter (api key)", "direct", "-", "-", "-", "-", "-", "error: \(.openrouter.error)"]]
     else [["openrouter (api key)", "direct", "-", "-", "-",
            "$\((.openrouter.total_credits - .openrouter.total_usage) * 100 | round / 100) left", "-", "-"]] end)
  | table;
'

# One row per upcoming reset: every Codex and Claude usage window, and each
# available Codex rate-limit reset credit by its expiry.
RESET_ROWS='
  def body: if . == null or (.status_code // 0) < 200 or .status_code >= 300 then null
    else (.body | fromjson? // null) end;
  def row($what; $detail; $at): {name: $name, tunnel: $tunnel, what: $what, detail: $detail, at: ($at | epoch)};
  ($usage | body) as $u
  | ($credits | body) as $c
  | if $u == null and $provider != "" then
      {name: $name, tunnel: $tunnel, what: "error", detail: "usage \($usage.error // "HTTP \($usage.status_code)")", at: null}
    elif $provider == "codex" then
      ([$u.rate_limit.primary_window, $u.rate_limit.secondary_window][] | select(. != null)
        | row((if lws == null then "window" elif lws > 86400 then "week window" else "5h window" end) + " resets";
            "\((.used_percent // .usedPercent) | pct) used";
            ((.reset_at // .resetAt) // (now + (.reset_after_seconds // .resetAfterSeconds // 0))))),
      (if $c == null then
        {name: $name, tunnel: $tunnel, what: "error",
         detail: "reset credits \($credits.error // "HTTP \($credits.status_code)")", at: null}
      else
        $c.credits // [] | .[]
        | select((.reset_type // .resetType) == "codex_rate_limits" and .status == "available")
        | row("reset credit expires"; "granted \((.granted_at // .grantedAt // "?")[0:10])"; (.expires_at // .expiresAt))
      end)
    else
      ([["five_hour", "5h"], ["seven_day", "7d"], ["seven_day_opus", "7d opus"],
        ["seven_day_sonnet", "7d sonnet"], ["iguana_necktie", "7d fable"],
        ["seven_day_oauth_apps", "7d oauth apps"], ["seven_day_cowork", "7d cowork"]][]
        | .[1] as $label | $u[.[0]]
        | select(. != null and .resets_at != null)
        | row("\($label) window resets"; "\(.utilization | pct) used"; .resets_at))
    end
'

RESETS_TABLE='
  def table_rows:
    [["CREDENTIAL", "TUNNEL", "RESET", "IN", "AT (UTC)", "DETAIL"]]
    + [sort_by(.at == null, .at)[]
       | [.name, .tunnel, .what, (if .at == null then "-" else .at - now | left end),
          (if .at == null then "-" else .at | floor | todate end), .detail]]
    | table;
'

reset_rows() {
  local file="$1" name provider index tunnel header usage="" credits=null
  name="$("$JQ" -r '.name' <<<"$file")"
  provider="$("$JQ" -r '.provider // .type // ""' <<<"$file")"
  index="$("$JQ" -r '.auth_index // ""' <<<"$file")"
  tunnel="$(tunnel_host "$name")"

  case "$provider" in
  codex)
    header="$(codex_header "$file")"
    usage="$(api_call "$index" "$name" GET "$CODEX_USAGE_URL" "$header" 2>&1)" ||
      usage="$("$JQ" -nc --arg error "${usage##*failed: }" '{error: $error}')"
    # A failed lookup becomes an error row; dropping it would undercount credits.
    credits="$(api_call "$index" "$name" GET "$CODEX_RESET_CREDITS_URL" \
      "$("$JQ" -c '. + {"Accept": "application/json", "OpenAI-Beta": "codex-1", "Originator": "Codex Desktop"}' <<<"$header")" 2>&1)" ||
      credits="$("$JQ" -nc --arg error "${credits##*failed: }" '{error: $error}')"
    ;;
  claude)
    usage="$(api_call "$index" "$name" GET "$CLAUDE_USAGE_URL" "$CLAUDE_HEADER" 2>&1)" ||
      usage="$("$JQ" -nc --arg error "${usage##*failed: }" '{error: $error}')"
    ;;
  *) return 0 ;;
  esac

  "$JQ" -nc --arg name "$name" --arg tunnel "$tunnel" --arg provider "$provider" \
    --argjson usage "$usage" --argjson credits "$credits" "$JQ_LIB $RESET_ROWS"
}

resets() {
  local as_json="$1" filter="$2" rows
  rows="$(
    management GET /auth-files |
      "$JQ" -c --arg filter "$filter" \
        '.files[] | select(((.disabled // false) | not) and ($filter == "" or (.name | contains($filter))))' |
      while IFS= read -r file; do
        reset_rows "$file"
      done | "$JQ" -sc '.'
  )"
  if [ "$as_json" = "true" ]; then
    "$JQ" --argjson rows "$rows" -n '$rows | sort_by(.at == null, .at)'
  else
    "$JQ" -rn --argjson rows "$rows" "$JQ_LIB $RESETS_TABLE \$rows | table_rows"
  fi
}

status() {
  local as_json="$1" filter="$2" files file records openrouter
  files="$(management GET /auth-files)"
  records="$(
    "$JQ" -c --arg filter "$filter" '.files[] | select($filter == "" or (.name | contains($filter)))' <<<"$files" |
      while IFS= read -r file; do
        account_record "$file"
      done | "$JQ" -sc '.'
  )"
  if [ -z "$filter" ]; then
    openrouter="$(openrouter_record)"
  else
    openrouter=null
  fi
  if [ "$as_json" = "true" ]; then
    "$JQ" -n --argjson accounts "$records" --argjson openrouter "$openrouter" \
      '{accounts: $accounts, openrouter: $openrouter}'
  else
    "$JQ" -rn --argjson accounts "$records" --argjson openrouter "$openrouter" \
      "$JQ_LIB $STATUS_TABLE {accounts: \$accounts, openrouter: \$openrouter} | table_rows"
  fi
}

# An exact name or auth index wins; otherwise every name containing the
# selector matches, and "all" matches every enabled credential.
matching_files() {
  local selector="$1"
  management GET /auth-files | "$JQ" -c --arg s "$selector" '
    .files as $files
    | [$files[] | select(.name == $s or .auth_index == $s)]
    | if length > 0 then . else [$files[] | select(($s == "all" and (.disabled | not)) or (.name | contains($s)))] end
    | .[]'
}

reset_cooldown() {
  local file="$1" name index
  name="$("$JQ" -r '.name' <<<"$file")"
  index="$("$JQ" -r '.auth_index' <<<"$file")"
  management POST /reset-quota "$("$JQ" -nc --arg index "$index" '{auth_index: $index}')" >/dev/null
  echo "$name: local cooldown cleared"
}

reset() {
  local selector="$1" file count=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    reset_cooldown "$file"
    count=$((count + 1))
  done < <(matching_files "$selector")
  [ "$count" -gt 0 ] || die "no credential matches '$selector'"
}

redeem_request_id() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  else
    uuidgen | tr '[:upper:]' '[:lower:]'
  fi
}

redeem() {
  local selector="$1" matches file name index header data response code
  matches="$(matching_files "$selector")"
  [ -n "$matches" ] || die "no credential matches '$selector'"
  [ "$(wc -l <<<"$matches")" -eq 1 ] || die "'$selector' matches more than one credential; name one"
  file="$matches"
  [ "$("$JQ" -r '.provider // .type' <<<"$file")" = "codex" ] || die "redeem only applies to codex credentials"
  name="$("$JQ" -r '.name' <<<"$file")"
  index="$("$JQ" -r '.auth_index' <<<"$file")"
  header="$(codex_header "$file")"
  data="$("$JQ" -nc --arg id "$(redeem_request_id)" '{redeem_request_id: $id}')"
  response="$(api_call "$index" "$name" POST "$CODEX_REDEEM_URL" "$header" "$data")"
  code="$("$JQ" -r '.status_code' <<<"$response")"
  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    die "$name: redeem failed with HTTP $code: $("$JQ" -r '.body' <<<"$response")"
  fi
  echo "$name: redeemed one rate-limit reset credit via $(tunnel_host "$name")"
  reset_cooldown "$file"
}

command="status"
case "${1:-}" in
-h | --help | help)
  usage
  exit 0
  ;;
status | resets | reset | redeem)
  command="$1"
  shift
  ;;
esac

[ -n "$MANAGEMENT_KEY" ] || die "CLIPROXY_MANAGEMENT_PASSWORD is not set in ~/dotfiles/.env"

case "$command" in
status | resets)
  as_json=false
  filter=""
  for arg in "$@"; do
    case "$arg" in
    --json) as_json=true ;;
    -*) die "unknown option: $arg" ;;
    *) filter="$arg" ;;
    esac
  done
  "$command" "$as_json" "$filter"
  ;;
reset)
  [ "$#" -eq 1 ] || {
    usage >&2
    exit 1
  }
  reset "$1"
  ;;
redeem)
  confirmed=false
  selector=""
  for arg in "$@"; do
    case "$arg" in
    --yes) confirmed=true ;;
    -*) die "unknown option: $arg" ;;
    *) selector="$arg" ;;
    esac
  done
  [ -n "$selector" ] || {
    usage >&2
    exit 1
  }
  [ "$confirmed" = "true" ] || die "redeem spends a Codex reset credit; pass --yes to confirm"
  redeem "$selector"
  ;;
esac
