#!/usr/bin/env bash

# Detect captive portals without interrupting the network connection.
set -euo pipefail

check_only=false
case ${1:-} in
  --check) check_only=true ;;
  '') ;;
  *) echo "Usage: $0 [--check]" >&2; exit 2 ;;
esac

curl_interface=()
network_key=default
if [[ $OSTYPE == darwin* ]]; then
  # SSID queries can be unavailable even while Wi-Fi is connected.
  wifi_device=$(networksetup -listallhardwareports 2>/dev/null | awk '
    /^Hardware Port: (Wi-Fi|AirPort)$/ { wifi = 1; next }
    wifi && /^Device: / { print $2; exit }
  ' || true)
  wifi_address=''
  if [[ -n $wifi_device ]]; then
    wifi_address=$(ipconfig getifaddr "$wifi_device" 2>/dev/null || true)
  fi
  if [[ -z $wifi_address ]]; then
    echo "$(date): OFFLINE (no Wi-Fi IPv4 address)"
    exit 0
  fi
  wifi_router=$(ipconfig getoption "$wifi_device" router 2>/dev/null || true)
  network_key="$wifi_device:$wifi_address:$wifi_router"
  curl_interface=(--interface "$wifi_device")
fi

probe_dir=$(mktemp -d)
trap 'rm -rf "$probe_dir"' EXIT
online=false
captive=false
portal_probe=''

probe() {
  local url=$1 expected=$2 status body
  # Ignore user curl config/proxies, preserve redirects, and bound each GET.
  if ! status=$(curl --disable --noproxy '*' "${curl_interface[@]}" \
    --silent --connect-timeout 2 --max-time 4 --max-filesize 65536 \
    --output "$probe_dir/body" --write-out '%{http_code}' "$url"); then
    return 0
  fi
  body=$(cat "$probe_dir/body")
  case $status in
    200)
      if [[ $expected != 204 && $body == "$expected" ]]; then
        online=true
      else
        captive=true
        portal_probe=$url
      fi
      ;;
    204)
      if [[ $expected == 204 && ! -s $probe_dir/body ]]; then
        online=true
      fi
      ;;
    301|302|303|307|308|511)
      captive=true
      portal_probe=$url
      ;;
  esac
}

probe http://captive.apple.com/hotspot-detect.html \
  '<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>'
probe http://connectivitycheck.gstatic.com/generate_204 204
probe http://www.msftconnecttest.com/connecttest.txt 'Microsoft Connect Test'

if [[ $captive == false ]]; then
  if [[ $online == true ]]; then
    echo "$(date): ONLINE"
  else
    echo "$(date): OFFLINE (connectivity probes unavailable)"
  fi
  exit 0
fi

# A whitelisted probe may succeed before login; interception takes precedence.
echo "$(date): CAPTIVE (login required)"
if [[ $check_only == true || $OSTYPE != darwin* ]]; then
  exit 0
fi

# Keep the cooldown across launchd runs and brief online/offline transitions.
umask 077
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/neverssl-keepalive"
mkdir -p "$state_dir"
network_id=$(printf '%s' "$network_key" | cksum)
network_id=${network_id%% *}
state_file="$state_dir/$network_id.last-opened"
now=$(date +%s)
last_opened=0
if [[ -f $state_file ]]; then
  read -r last_opened <"$state_file" || last_opened=0
fi
if [[ ! $last_opened =~ ^[0-9]{1,12}$ ]]; then
  last_opened=0
fi
last_opened=$((10#$last_opened))
if (( now >= last_opened && now - last_opened < 600 )); then
  exit 0
fi

# Open a known HTTP probe, letting the browser follow the network's login flow.
# Never pass a network-provided redirect URL to the local application launcher.
if open "$portal_probe"; then
  printf '%s\n' "$now" >"$state_file"
else
  echo "$(date): Could not open captive portal" >&2
fi
