#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "utils.sh"

pwd
~/.auto_sync_bundle.sh || ../bundle/.auto_sync_bundle.sh
~/.auto_sync_brew.sh || ../brew/.auto_sync_brew.sh
~/.auto_sync_pipenv.sh || ../pipenv/.auto_sync_pipenv.sh
~/.auto_sync_yarn.sh || ../yarn/.auto_sync_yarn.sh
~/.auto_sync_mackup.sh || true
