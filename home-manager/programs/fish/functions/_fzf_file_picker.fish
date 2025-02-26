function _fzf_file_picker --description="fzf file picker"
    set -l show_hidden_files false
    set -l path '.'
    set -l prompt_name Files
    set -l allow_open_in_editor

    if test (count $argv) -gt 0
        for i in (seq (count $argv))
            if test "$argv[$i]" = --show-hidden-files
                set show_hidden_files true
            else if test "$argv[$i]" = --prompt-name
                # Check if there is another argument after "--prompt-name"
                if test (math $i + 1) -le (count $argv)
                    set prompt_name $argv[(math $i + 1)]
                end
            else if test "$argv[$i]" = --allow-open-in-editor
                set allow_open_in_editor 1
            else
                # Check if there is another argument after the current one
                if test (count $argv) -ge (math $i + 1)
                    set path (echo $argv[(math $i + 1)] | sed 's:/*$::')
                end
            end
        end
    end

    set -l selected_path

    if $show_hidden_files
        set selected_path (fd . $path --type f --type d --hidden | fzf --preview="_fzf_preview_cmd {}" --prompt=(_fzf_preview_name $prompt_name))
    else
        set selected_path (fd . $path --type f --type d --exclude .git --exclude .gitignore 2>/dev/null | sed 's|^\$path/||' | fzf --preview="_fzf_preview_cmd {}" --prompt=(_fzf_preview_name $prompt_name))
    end

    if test -n "$selected_path"

        if test -n "$allow_open_in_editor"
            if not set -q EDITOR
                echo "Error: \$EDITOR is not set. Please configure your preferred editor using 'set -Ux EDITOR your-editor'"
                return 1
            end

            if not command -q $EDITOR
                echo "Error: Editor '$EDITOR' not found. Please make sure it is installed and in your PATH."
                return 1
            end

            $EDITOR $path/$selected_path
        else
            commandline --current-token --replace -- (string escape -- $path/$selected_path)
        end
    end

    commandline --function repaint
end
