#!/usr/bin/env bash
# Thin shim that delegates to the Nix-store install-yek script.
# @bash@ and @install_yek_script@ are substituted by pkgs.replaceVars.
exec @bash@/bin/bash @install_yek_script@ "$@"
