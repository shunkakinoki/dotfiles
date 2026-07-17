#!/usr/bin/env bash

set -euo pipefail

nightlight_bin="@nightlightBin@"
temperature=@temperature@

# A sunset-to-sunrise schedule turns Night Shift back off at sunrise, so the
# schedule has to be cleared before `on` can mean "stays on".
"$nightlight_bin" schedule stop
"$nightlight_bin" temp "$temperature"
"$nightlight_bin" on
