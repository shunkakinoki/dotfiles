#!/usr/bin/env bash

set -euo pipefail

/bin/launchctl setenv BEADS_DOLT_AUTO_START 0
/bin/launchctl setenv BEADS_DOLT_SERVER_MODE 1
/bin/launchctl setenv BEADS_DOLT_SERVER_HOST "@doltServerHost@"
/bin/launchctl setenv BEADS_DOLT_SERVER_PORT 3307
/bin/launchctl setenv BEADS_DOLT_SERVER_USER beads
/bin/launchctl setenv DOLT_CLI_USER root
/bin/launchctl setenv DOLT_CLI_PASSWORD ""
