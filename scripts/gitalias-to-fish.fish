#!/usr/bin/env fish
# Convert GitAlias to fish abbreviations

set GITALIAS_URL "https://raw.githubusercontent.com/GitAlias/gitalias/main/gitalias.txt"
set TEMP_FILE (mktemp)

# Download GitAlias file
curl -fsSL "$GITALIAS_URL" -o "$TEMP_FILE"

# Parse and convert to fish abbreviations
grep -E '^\s*[a-zA-Z0-9_-]+\s*=' "$TEMP_FILE" | while read -l line
    # Skip comments
    if string match -qr '^\s*#' -- $line
        continue
    end

    # Extract alias name (before =)
    set alias_name (string trim (string split -m 1 '=' $line)[1])
    # Extract alias command (after =)
    set alias_cmd (string trim (string replace -r '^[^=]+=' '' -- $line))

    # Skip empty aliases
    if test -z "$alias_name" -o -z "$alias_cmd"
        continue
    end

    # Skip complex aliases with problematic patterns
    if string match -qr '\\$|%C|^!|GIT_|!\s|![a-z]|@\{|\\'\''|"!' -- $alias_cmd
        continue
    end

    # Escape single quotes for fish
    set alias_cmd (string replace -a "'" "\\'" -- $alias_cmd)

    # Output fish abbreviation
    echo "abbr -a g$alias_name 'git $alias_cmd'"
end

# Cleanup
rm -f "$TEMP_FILE"
