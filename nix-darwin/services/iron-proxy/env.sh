#!/usr/bin/env bash
set -u

state_dir="@stateDir@"
proxy_url="http://127.0.0.1:@proxyPort@"
no_proxy="@noProxy@"
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
