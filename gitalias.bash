#!/usr/bin/env bash
# Source this file in your .bashrc to load GitAlias aliases
# Example: source /path/to/gitalias.bash

# Generate and evaluate GitAlias bash aliases
_gitalias_dir="$(dirname "${BASH_SOURCE[0]}")"
while IFS= read -r line; do
  eval "$line"
done < <(bash "$_gitalias_dir/scripts/gitalias-to-bash.sh")
