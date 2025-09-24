function fish_shortcuts --description "List fish abbreviations and aliases with inferred descriptions"
    # Prints all abbreviations and aliases currently active in this shell.
    # For items that expand to a function, attempts to extract a description from:
    #  1) the function's --description flag, or
    #  2) the first leading comment lines inside the function body.

    function __fish__get_func_desc --argument-names fname
        if not functions -q $fname
            return 1
        end

        # Get the full function definition as a single string
        set -l def (functions $fname | string collect)

        # Try to extract --description from the function header
        set -l desc_line (string match -r -- 'function\s+\S+.*--description(=| )[\"\'].*' -- $def)
        if test -n "$desc_line"
            # Try double-quoted first
            set -l d (string replace -r -- '.*--description(=| )\"([^\"]+)\".*' '$2' -- $desc_line)
            if test -n "$d"
                echo $d
                return 0
            end
            # Fallback to single-quoted
            set -l d (string replace -r -- ".*--description(=| )'([^']+)'.*" '$2' -- $desc_line)
            if test -n "$d"
                echo $d
                return 0
            end
        end

        # Fallback: first non-empty leading comment line after the header
        set -l lines (functions $fname | string split \n)
        set -l got_header 0
        for line in $lines
            if test $got_header -eq 0
                # Skip the header line: it starts with "function "
                if string match -rq '^\s*function\s' -- $line
                    set got_header 1
                end
                continue
            end
            if string match -rq '^\s*#' -- $line
                set -l cleaned (string replace -r -- '^\s*#\s*' '' -- $line)
                if test -n "$cleaned"
                    echo $cleaned
                    return 0
                end
            else
                # Stop scanning once non-comment code begins
                break
            end
        end

        return 1
    end

    function __fish__format_row --argument-names kind name expansion desc
        # kind: "abbr" | "alias"
        if test -n "$desc"
            printf "%s\t%-20s -> %-40s # %s\n" $kind $name $expansion $desc
        else
            printf "%s\t%-20s -> %s\n" $kind $name $expansion
        end
    end

    set -l any_output 0

    # Abbreviations
    if type -q abbr
        set -l abbr_list (abbr --list 2>/dev/null)
        set -l abbr_show (abbr --show 2>/dev/null)

        for a in $abbr_list
            # Find the matching line for this abbreviation in the abbr --show output
            set -l line (printf "%s\n" $abbr_show | string match -r -- "^"(string escape --style=regex -- $a)"(\b|\s).*")
            set -l expansion ""
            if test -n "$line"
                # Extract the expansion part after '->'
                set expansion (string replace -r -- '^[^>]+->\s*' '' -- $line)
            end

            set -l desc ""
            # If the expansion is a single token and is a function, derive description
            if test -n "$expansion"
                set -l first_token (string split ' ' -- $expansion)[1]
                if test (count (string split ' ' -- $expansion)) -eq 1; and functions -q $first_token
                    set desc (__fish__get_func_desc $first_token)
                end
            end

            __fish__format_row abbr $a "$expansion" "$desc"
            set any_output 1
        end
    end

    # Aliases
    if type -q alias
        for line in (alias 2>/dev/null)
            # line format typically: alias NAME 'EXPANSION...'
            set -l name (string replace -r -- '^alias\s+([^\s]+).*$' '$1' -- $line)
            set -l expansion (string replace -r -- "^alias\s+[^\s]+\s+'([^']*)'.*$" '$1' -- $line)

            set -l desc ""
            if test -n "$expansion"
                set -l first_token (string split ' ' -- $expansion)[1]
                if test (count (string split ' ' -- $expansion)) -eq 1; and functions -q $first_token
                    set desc (__fish__get_func_desc $first_token)
                end
            end

            __fish__format_row alias $name "$expansion" "$desc"
            set any_output 1
        end
    end

    if test $any_output -eq 0
        echo "No abbreviations or aliases found."
    end
end
