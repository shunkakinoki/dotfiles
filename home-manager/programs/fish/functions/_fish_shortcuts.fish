function _fish_shortcuts --description "List fish abbreviations and aliases with inferred descriptions"
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
        set -l d (string match -r --groups-only -- '--description(?:=| )\"([^\"]*)\"' "$def")
        if test -n "$d"
            echo $d
            return 0
        end

        set d (string match -r --groups-only -- "--description(?:=| )'([^']*)'" "$def")
        if test -n "$d"
            echo $d
            return 0
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

        for a in $abbr_list
            set -l expansion ""
            set -l show_line (abbr --show $a 2>/dev/null | string collect)
            if test -n "$show_line"
                if type -q python3
                    set -lx __FISH_SHORTCUT_LINE "$show_line"
                    set expansion (python3 -c "import os, shlex, sys; line = os.environ['__FISH_SHORTCUT_LINE']; tokens = shlex.split(line); rest = tokens[tokens.index('--') + 2:]; pos = rest.index('--function') if '--function' in rest else -1; exp = rest[pos + 1] if pos != -1 and pos + 1 < len(rest) else (' '.join(rest) if rest else ''); sys.stdout.write(exp)")
                    set -e __FISH_SHORTCUT_LINE
                end

                if test -z "$expansion"
                    set expansion (string match -r --groups-only ".*'([^']*)'" -- "$show_line")
                end
                if test -z "$expansion"
                    set expansion (string match -r --groups-only '.*"([^"]*)"' -- "$show_line")
                end
                if test -z "$expansion"
                    set -l fallback (string replace -r -- '^abbr\b.* -- \S+\s+' '' -- "$show_line")
                    set fallback (string trim -- $fallback)
                    if test -n "$fallback"
                        set expansion $fallback
                    end
                end
                if test -n "$expansion"
                    set expansion (string trim --chars="'\"" -- $expansion)
                end
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
            set -l name ""
            set -l expansion ""

            set -l alias_parts (string split -m 2 ' ' -- $line)
            if test (count $alias_parts) -ge 2
                set name $alias_parts[2]
            end
            if test (count $alias_parts) -ge 3
                set expansion (string trim --chars="'" -- $alias_parts[3])
            end

            if test -z "$name"
                # Skip lines we fail to parse (unexpected alias output format)
                continue
            end

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

    # Functions stored alongside this helper
    set -l script_path (status current-filename)
    set -l script_realpath ""
    if test -n "$script_path"
        if type -q realpath
            set script_realpath (realpath "$script_path" 2>/dev/null)
        end
        if test -z "$script_realpath"
            set script_realpath $script_path
        end
    end

    set -l functions_dir ""
    set -l functions_parent ""
    if test -n "$script_realpath"
        set functions_dir (path dirname $script_realpath)
        set functions_parent (path dirname $functions_dir)
    end

    if test -n "$functions_dir"; and test -d "$functions_dir"
        set -l function_files $functions_dir/*.fish
        if test "$function_files" = "$functions_dir/*.fish"
            set function_files
        end

        for file in $function_files
            if test -z "$file"; or test ! -f "$file"
                continue
            end

            set -l base (path basename $file)
            set -l fname (path change-extension '' -- $base)

            # Avoid re-sourcing ourselves repeatedly
            if test "$fname" = (status function)
                continue
            end

            if not functions -q $fname
                builtin source $file 2>/dev/null
            end

            set -l desc (__fish__get_func_desc $fname)
            set -l rel_path "$base"
            if test -n "$functions_parent"
                set rel_path (string join '' "functions/" $base)
            end

            __fish__format_row func $fname "$rel_path" "$desc"
            set any_output 1
        end
    end

    if test $any_output -eq 0
        echo "No abbreviations or aliases found."
    end
end

if not functions -q fish_shortcuts
    function fish_shortcuts --wraps _fish_shortcuts --description "Alias for _fish_shortcuts"
        _fish_shortcuts $argv
    end
end
