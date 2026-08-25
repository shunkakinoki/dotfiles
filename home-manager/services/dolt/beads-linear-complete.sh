#!/usr/bin/env bash

set -euo pipefail

exec "@bash@/bin/bash" "@linearSyncScript@" --complete "$@"
