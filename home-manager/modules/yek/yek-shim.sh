#!/usr/bin/env bash
# Thin shim that delegates to the Nix-store yek wrapper script.
# @bash@ and @yek_wrapper_script@ are substituted by pkgs.replaceVars.
exec @bash@/bin/bash @yek_wrapper_script@ "$@"
