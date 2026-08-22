function copy --description "Copy text, images, or files to the clipboard"
    set -l scripts $HOME/.local/scripts
    if test (count $argv) -eq 0
        $scripts/clipboard-copy
        return
    end
    set -l target $argv[1]
    if test -f "$target"
        switch (string lower "$target")
            case '*.png' '*.jpg' '*.jpeg' '*.gif' '*.webp' '*.tif' '*.tiff' '*.bmp' '*.heic' '*.ico'
                $scripts/clipboard-copy-image "$target"
                return
        end
        $scripts/clipboard-copy-file "$target"
        return
    end
    if test -e "$target"
        printf 'copy: not a regular file: %s\n' "$target" >&2
        return 1
    end
    printf '%s\n' (string join ' ' $argv) | $scripts/clipboard-copy
end
