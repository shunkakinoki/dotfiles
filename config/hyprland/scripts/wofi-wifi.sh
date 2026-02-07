#!/usr/bin/env bash
# Wofi-based WiFi network picker using nmcli

notify-send "WiFi" "Scanning networks..." -t 2000

# Get list of available networks (deduplicated by SSID)
NETWORKS=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list --rescan yes |
  awk -F: '!seen[$1]++ && $1!=""' |
  sort -t: -k2 -rn |
  awk -F: '{
        signal=$2
        sec=$3
        lock=""
        if (sec != "" && sec != "--") lock=" [secured]"
        printf "%s  %s%%%s\n", $1, signal, lock
    }')

if [ -z "$NETWORKS" ]; then
  notify-send "WiFi" "No networks found"
  exit 1
fi

# Show wofi picker
CHOSEN=$(echo "$NETWORKS" | wofi --dmenu --prompt "WiFi Network" --width 400 --height 300)

if [ -z "$CHOSEN" ]; then
  exit 0
fi

# Extract SSID (everything before the signal percentage)
SSID="${CHOSEN%%  [0-9]*}"

# Check if already connected
CURRENT=$(nmcli -t -f NAME connection show --active | head -1)
if [ "$CURRENT" = "$SSID" ]; then
  notify-send "WiFi" "Already connected to $SSID"
  exit 0
fi

# Check if we have a saved connection
if nmcli -t -f NAME connection show | grep -qx "$SSID"; then
  if nmcli connection up "$SSID"; then
    notify-send "WiFi" "Connected to $SSID"
  else
    notify-send "WiFi" "Failed to connect to $SSID"
  fi
else
  # Need password — check if secured
  if echo "$CHOSEN" | grep -q "\[secured\]"; then
    PASSWORD=$(echo "" | wofi --dmenu --prompt "Password for $SSID" --password --width 400 --height 100)
    if [ -n "$PASSWORD" ]; then
      if nmcli device wifi connect "$SSID" password "$PASSWORD"; then
        notify-send "WiFi" "Connected to $SSID"
      else
        notify-send "WiFi" "Failed to connect to $SSID"
      fi
    fi
  else
    if nmcli device wifi connect "$SSID"; then
      notify-send "WiFi" "Connected to $SSID"
    else
      notify-send "WiFi" "Failed to connect to $SSID"
    fi
  fi
fi
