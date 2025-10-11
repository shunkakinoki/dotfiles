#!/usr/bin/env zsh
# Source this file in your .zshrc to load GitAlias aliases
# Example: source /path/to/gitalias.zsh

# Generate and evaluate GitAlias zsh aliases
_gitalias_dir="$(dirname "${(%):-%x}")"
zsh "$_gitalias_dir/scripts/gitalias-to-zsh.sh" | while IFS= read -r line; do
  eval "$line"
done
