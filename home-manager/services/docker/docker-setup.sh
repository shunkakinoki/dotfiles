#!/usr/bin/env bash
# Thin wrapper exposing setup-docker as a user-facing command.
# @setup_docker_script@ is substituted by pkgs.replaceVars.
exec @setup_docker_script@
