#!/usr/bin/env bash
# Wraps the fishtape fish plugin so it can be called as a regular command.
# @fish@ and @fishtape_3_src@ are substituted by pkgs.replaceVars.
# shellcheck disable=SC2016
exec @fish@/bin/fish \
  -C "source @fishtape_3_src@/functions/fishtape.fish" \
  -c 'fishtape $argv' \
  -- "$@"
