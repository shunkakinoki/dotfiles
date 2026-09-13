#!/usr/bin/env bash
# List the declared Kamino family or verify its enrolled SSH endpoints.
set -euo pipefail

usage() {
  printf '%s\n' 'usage: kamino-fleet --inventory FILE list|verify [PATTERN] [--json]' >&2
  return 2
}

inventory=
command=
pattern=kamino\*
as_json=false

while [ "$#" -gt 0 ]; do
  case "$1" in
  --inventory)
    [ "$#" -ge 2 ] || usage
    inventory=$2
    shift 2
    ;;
  --json)
    as_json=true
    shift
    ;;
  list | verify)
    [ -z "$command" ] || usage
    command=$1
    shift
    ;;
  --help | -h)
    usage
    ;;
  *)
    [ "$pattern" = 'kamino*' ] || usage
    pattern=$1
    shift
    ;;
  esac
done

[ -n "$inventory" ] && [ -n "$command" ] || usage
[ -r "$inventory" ] || {
  printf 'kamino-fleet: inventory is not readable\n' >&2
  exit 2
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

selected="$tmp_dir/selected.jsonl"
: >"$selected"
while IFS= read -r machine; do
  name=$(jq -r '.name' <<<"$machine")
  # Pattern intentionally uses shell glob semantics for fnmatch-compatible selection.
  # shellcheck disable=SC2053
  if [[ $name == $pattern ]]; then
    printf '%s\n' "$machine" >>"$selected"
  fi
done < <(jq -c '.machines[]' "$inventory" 2>/dev/null) || {
  printf 'kamino-fleet: invalid inventory\n' >&2
  exit 2
}

[ -s "$selected" ] || {
  printf 'kamino-fleet: No declared machines match %q\n' "$pattern" >&2
  exit 2
}

emit_results() {
  local result_file=$1
  if "$as_json"; then
    jq -s '.' "$result_file"
  else
    while IFS= read -r result; do
      jq -r '[.name, .status, (.reason // .hostname)] | @tsv' <<<"$result"
    done <"$result_file"
  fi
}

if [ "$command" = list ]; then
  result_file="$tmp_dir/results.jsonl"
  while IFS= read -r machine; do
    jq -c '. + {status: "declared"}' <<<"$machine" >>"$result_file"
  done <"$selected"
  emit_results "$result_file"
  exit 0
fi

status_json="$tmp_dir/tailscale-status.json"
if ! tailscale status --json >"$status_json" 2>/dev/null; then
  printf 'kamino-fleet: Tailscale is not running and authenticated\n' >&2
  exit 2
fi
if ! jq -e 'type == "object" and .BackendState == "Running" and ((.Peer // {}) | type == "object")' "$status_json" >/dev/null 2>&1; then
  printf 'kamino-fleet: Tailscale is not running and authenticated\n' >&2
  exit 2
fi
jq -c '[((.Peer // {}) | .[]), .Self?] | map(select(type == "object"))' "$status_json" >"$tmp_dir/nodes.json" || {
  printf 'kamino-fleet: Invalid Tailscale peer inventory\n' >&2
  exit 2
}

results="$tmp_dir/results.jsonl"
: >"$results"
while IFS= read -r machine; do
  name=$(jq -r '.name' <<<"$machine")
  hostname=$(jq -r '.hostname' <<<"$machine")
  user=$(jq -r '.user' <<<"$machine")
  result=$(jq -c '. + {status: "fail", node_id: null}' <<<"$machine")
  matches=$(jq --arg hostname "$hostname" '[.[] | select((.DNSName // "" | rtrimstr(".") | ascii_downcase) == ($hostname | ascii_downcase))] | length' "$tmp_dir/nodes.json")
  if [ "$matches" -ne 1 ]; then
    reason='missing or not visible'
    [ "$matches" -gt 1 ] && reason='duplicate DNS name'
    jq -c --arg reason "$reason" '. + {reason: $reason}' <<<"$result" >>"$results"
    continue
  fi
  node=$(jq -c --arg hostname "$hostname" '[.[] | select((.DNSName // "" | rtrimstr(".") | ascii_downcase) == ($hostname | ascii_downcase))][0]' "$tmp_dir/nodes.json")
  node_id=$(jq -r '.ID // empty' <<<"$node")
  ids=$(jq --arg id "$node_id" '[.[] | select(.ID == $id)] | length' "$tmp_dir/nodes.json")
  if [ -z "$node_id" ] || [ "$ids" -ne 1 ]; then
    jq -c '. + {reason: "missing or duplicate Tailscale device ID"}' <<<"$result" >>"$results"
    continue
  fi
  if [ "$(jq -r '.Online // false' <<<"$node")" != true ]; then
    jq -c '. + {node_id: $id, reason: "offline"}' --arg id "$node_id" <<<"$result" >>"$results"
    continue
  fi
  if ! jq -e '(.TailscaleIPs // []) | if length == 0 then false else (.[0] | type == "string" and test("^[0-9A-Fa-f:.]+$")) end' <<<"$node" >/dev/null 2>&1; then
    jq -c '. + {node_id: $id, reason: "missing or invalid Tailscale IP"}' --arg id "$node_id" <<<"$result" >>"$results"
    continue
  fi
  probe='export XDG_RUNTIME_DIR=/run/user/0; id -un && hostname && /root/.nix-profile/bin/herdr --version && /root/.nix-profile/bin/tmux -V && /root/.nix-profile/bin/zellij --version && /usr/bin/systemctl --user is-active herdr-server && /root/.nix-profile/bin/herdr status server >/dev/null'
  if ! output=$(tailscale ssh "$user@$hostname" "/bin/sh -c '$probe'" 2>/dev/null); then
    jq -c '. + {node_id: $id, reason: "SSH or tools/service probe failed; check login, host key and Herdr"}' --arg id "$node_id" <<<"$result" >>"$results"
    continue
  fi
  lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done <<<"$output"
  if [ "${#lines[@]}" -ne 6 ] || [ "${lines[0]}" != "$user" ]; then
    reason='unexpected SSH user or probe output'
  elif [ "${lines[1]%%.*}" != "$name" ]; then
    reason='SSH hostname differs from declaration'
  elif [ "${lines[5]}" != active ] || [ -z "${lines[2]}" ] || [ -z "${lines[3]}" ] || [ -z "${lines[4]}" ]; then
    reason='tools or Herdr service not healthy'
  else
    jq -c '. + {status: "pass", node_id: $id, reason: "identity, Herdr server, tmux and Zellij verified", versions: $versions}' \
      --arg id "$node_id" --argjson versions "$(printf '%s\n' "${lines[@]:2:3}" | jq -Rsc 'split("\n")[:-1]')" <<<"$result" >>"$results"
    continue
  fi
  jq -c --arg id "$node_id" --arg reason "$reason" '. + {node_id: $id, reason: $reason}' <<<"$result" >>"$results"
done <"$selected"

emit_results "$results"
if jq -e 'any(.[]; .status == "fail")' < <(jq -s '.' "$results") >/dev/null; then
  exit 1
fi
