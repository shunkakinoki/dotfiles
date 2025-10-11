#!/usr/bin/env fish
# Source this file in your config.fish to load GitAlias abbreviations
# Example: source /path/to/gitalias.fish

# Generate and evaluate GitAlias fish abbreviations
set script_dir (status dirname)
for line in (fish "$script_dir/scripts/gitalias-to-fish.fish")
    eval $line
end
