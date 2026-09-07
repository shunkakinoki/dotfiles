function _cliproxyapi_priority_function --description "Pin cliproxyapi OAuth credentials to a routing priority"
    set -l target 300

    if test (count $argv) -gt 1
        echo "Usage: clpri [priority]" >&2
        return 1
    end

    if test (count $argv) -eq 1
        if not string match -qr '^[0-9]+$' -- $argv[1]
            echo "Usage: clpri [priority]" >&2
            return 1
        end
        set target $argv[1]
    end

    if not command -q jq
        echo "clpri: jq is required" >&2
        return 1
    end

    set -l auth_dir "$HOME/.cli-proxy-api/objectstore/auths"
    if not test -d "$auth_dir"
        echo "clpri: auth dir not found: $auth_dir" >&2
        return 1
    end

    set -l files $auth_dir/*.json
    if test (count $files) -eq 0
        echo "clpri: no credentials in $auth_dir"
        return 0
    end

    set -l patched 0
    set -l failed 0

    for f in $files
        test -f "$f"; or continue

        if not jq -e 'type == "object"' "$f" >/dev/null 2>&1
            echo "clpri: skipping unparseable credential: "(basename "$f") >&2
            set failed (math $failed + 1)
            continue
        end

        set -l current (jq -r '.priority // 0' "$f")
        test "$current" = "$target"; and continue

        set -l tmp (mktemp)
        if jq --argjson p $target '.priority = $p' "$f" >$tmp
            # Preserve the credential's mode; mktemp creates 0600 but an
            # existing file may be looser and cliproxy re-reads it in place.
            cat $tmp >"$f"
            rm -f $tmp
            echo (basename "$f")": $current -> $target"
            set patched (math $patched + 1)
        else
            rm -f $tmp
            echo "clpri: failed to patch "(basename "$f") >&2
            set failed (math $failed + 1)
        end
    end

    echo "clpri: $patched of "(count $files)" credential(s) updated to priority $target"

    test $failed -eq 0
end
