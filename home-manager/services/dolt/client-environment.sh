#!/usr/bin/env bash

set -euo pipefail

/bin/launchctl setenv BEADS_DOLT_AUTO_START 0
/bin/launchctl unsetenv BEADS_DOLT_DATA_DIR
/bin/launchctl unsetenv BEADS_FEDERATION_HUB
/bin/launchctl setenv BEADS_DOLT_SERVER_MODE 1
/bin/launchctl setenv BEADS_DOLT_SERVER_HOST "@doltServerHost@"
/bin/launchctl setenv BEADS_DOLT_SERVER_PORT 3307
/bin/launchctl setenv BEADS_DOLT_SERVER_USER beads
/bin/launchctl setenv BEADS_NODE_ID kyber
/bin/launchctl setenv DOLT_CLI_USER beads
/bin/launchctl setenv DOLT_CLI_PASSWORD ""
