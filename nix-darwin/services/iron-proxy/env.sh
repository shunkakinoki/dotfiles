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
if [ -e "$state_dir/env-ready" ]; then
  for key in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY; do
    "$launchctl_bin" setenv "$key" "$proxy_url"
  done
  for key in NO_PROXY no_proxy; do
    "$launchctl_bin" setenv "$key" "$no_proxy"
  done
  "$launchctl_bin" setenv NODE_USE_ENV_PROXY 1
  "$launchctl_bin" setenv NODE_EXTRA_CA_CERTS "$state_dir/ca.crt"
  for key in SSL_CERT_FILE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE; do
    "$launchctl_bin" setenv "$key" "$state_dir/ca-bundle.crt"
  done
else
  for key in HTTPS_PROXY HTTP_PROXY https_proxy http_proxy ALL_PROXY NO_PROXY no_proxy \
    NODE_USE_ENV_PROXY NODE_EXTRA_CA_CERTS SSL_CERT_FILE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE; do
    "$launchctl_bin" unsetenv "$key"
  done
fi
