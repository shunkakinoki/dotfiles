#!/usr/bin/env bash

Describe 'CPA Manager Plus service'
NIX_MODULE="$PWD/home-manager/services/cpa-manager-plus/default.nix"
START_SCRIPT="$PWD/home-manager/services/cpa-manager-plus/start.sh"
DOCKER_START_SCRIPT="$PWD/home-manager/services/cpa-manager-plus/docker-start.sh"

It 'is enabled only on Kyber Linux'
When run grep 'pkgs.stdenv.isLinux && host.isKyber' "$NIX_MODULE"
The output should include 'pkgs.stdenv.isLinux && host.isKyber'
End

It 'starts after Docker and CLIProxyAPI'
When run grep -A 8 'After = ' "$NIX_MODULE"
The output should include 'docker.service'
The output should include 'cliproxyapi.service'
End

It 'uses the Docker group wrapper and allows a clean shutdown window'
When run grep -E 'dockerStartScript|TimeoutStopSec = 45' "$NIX_MODULE"
The output should include 'dockerStartScript'
The output should include 'TimeoutStopSec = 45'
End

It 'restarts when Home Manager changes the unit'
When run grep 'X-RestartIfChanged' "$NIX_MODULE"
The output should include 'X-RestartIfChanged'
End

It 'falls back to the host Docker group wrappers'
When run grep -E '/run/wrappers/bin/sg|/usr/bin/sg' "$DOCKER_START_SCRIPT"
The output should include '/run/wrappers/bin/sg'
The output should include '/usr/bin/sg'
End

It 'runs the published manager image on the host network'
When run grep -E 'seakee/cpa-manager-plus:latest|--network host' "$START_SCRIPT"
The output should include 'seakee/cpa-manager-plus:latest'
The output should include '--network host'
End

It 'persists SQLite and the encryption key under the data mount'
When run grep -E 'USAGE_DB_PATH=/data/usage.sqlite|CPA_MANAGER_DATA_KEY_PATH=/data/data.key' "$START_SCRIPT"
The output should include 'USAGE_DB_PATH=/data/usage.sqlite'
The output should include 'CPA_MANAGER_DATA_KEY_PATH=/data/data.key'
End

It 'restricts the persistent data directory to the service user'
When run grep -E 'umask 077|chmod 700' "$START_SCRIPT"
The output should include 'umask 077'
The output should include 'chmod 700'
End

It 'connects to the local CPA without exposing the management key'
When run grep -E 'CPA_UPSTREAM_URL=http://127.0.0.1:8317|-e CPA_MANAGEMENT_KEY' "$START_SCRIPT"
The output should include 'CPA_UPSTREAM_URL=http://127.0.0.1:8317'
The output should include '-e CPA_MANAGEMENT_KEY'
The output should not include 'CPA_MANAGEMENT_KEY=${management_key}'
End
End
