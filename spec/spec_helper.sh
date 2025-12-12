#!/usr/bin/env bash

set -eu

spec_helper_precheck() {
  minimum_version "0.28.1"
}

spec_helper_configure() {
  import 'support/custom_matcher'
}
