#!/usr/bin/env bash
set -u

state_dir="@stateDir@"
proxy_url="http://127.0.0.1:@proxyPort@"
no_proxy="@noProxy@"
swap_keys="@secretsDir@/swap-keys"
exporter_label="org.nix-community.home.dotenv-gui-environment"
launchctl_bin="${LAUNCHCTL_BIN:-/bin/launchctl}"

# Apps launched from the Dock inherit these, including terminals and the CLIs
# that Claude Desktop and Codex spawn, which ignore the system proxy settings.
# Fails open: until the guard marks the proxy listening and its CA trusted,
# the variables are removed so TLS clients that read the Keychain keep working.
proxy_keys="HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY all_proxy"
no_proxy_keys="NO_PROXY no_proxy"
bundle_keys="SSL_CERT_FILE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE"

value_for() {
  case " $proxy_keys " in *" $1 "*) echo "$proxy_url" && return ;; esac
  case " $no_proxy_keys " in *" $1 "*) echo "$no_proxy" && return ;; esac
  case " $bundle_keys " in *" $1 "*) echo "$state_dir/ca-bundle.crt" && return ;; esac
  case "$1" in
  NODE_USE_ENV_PROXY) echo 1 ;;
  NODE_EXTRA_CA_CERTS) echo "$state_dir/ca.crt" ;;
  esac
}

for key in $proxy_keys $no_proxy_keys $bundle_keys NODE_USE_ENV_PROXY NODE_EXTRA_CA_CERTS; do
  value="$(value_for "$key")"
  if [ -e "$state_dir/env-ready" ]; then
    "$launchctl_bin" setenv "$key" "$value"
  # Only values this agent set are removed, so keys the dotenv GUI exporter
  # owns (a corporate CA bundle, say) survive while the proxy is down.
  elif [ "$("$launchctl_bin" getenv "$key")" = "$value" ]; then
    "$launchctl_bin" unsetenv "$key"
  fi
done

# The dotenv exporter decides between real secrets and swap placeholders from
# the proxy env set above, but only runs every few minutes. Rerun it as soon
# as a swapped key disagrees with the current state, so a dead proxy never
# leaves placeholders in the GUI session. `iron-proxy-secrets off` deletes
# swap-keys, so the last copy is kept to find placeholders left behind.
seen_keys="${IRON_PROXY_SEEN_KEYS:-$HOME/Library/Caches/iron-proxy-swap-keys}"
ready=""
if [ -r "$swap_keys" ]; then
  [ -e "$state_dir/env-ready" ] && ready=1
  mkdir -p "$(dirname "$seen_keys")" && cp "$swap_keys" "$seen_keys"
  keys_file="$swap_keys"
else
  keys_file="$seen_keys"
fi
if [ -r "$keys_file" ]; then
  stale=""
  while IFS= read -r key || [ -n "$key" ]; do
    [ -n "$key" ] || continue
    placeholder=""
    [ "$("$launchctl_bin" getenv "$key")" = "iron-proxy-swap-$key" ] && placeholder=1
    if [ "$placeholder" != "$ready" ]; then
      stale=1
      "$launchctl_bin" kickstart "gui/$(id -u)/$exporter_label" >/dev/null 2>&1 || true
      break
    fi
  done <"$keys_file"
  if [ -z "$stale" ] && [ "$keys_file" = "$seen_keys" ]; then
    rm -f "$seen_keys"
  fi
fi
