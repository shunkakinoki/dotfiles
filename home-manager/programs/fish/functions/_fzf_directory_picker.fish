function _fzf_directory_picker --description="fzf directory picker"
    set -l path '.'
    set -l recursive_depth 1
    set -l prompt_name 'Directory (Multilevel)'
    set -l allow_cd

    if test (count $argv) -gt 0
        for i in (seq (count $argv))
            if test "$argv[$i]" = --recursive-depth
                # Check if there is another argument after "--recursive-depth"
                if test (math $i + 1) -le (count $argv)
                    set recursive_depth $argv[(math $i + 1)]
                end
            else if test "$argv[$i]" = --prompt-name
                # Check if there is another argument after "--prompt-name"
                if test (math $i + 1) -le (count $argv)
                    set prompt_name $argv[(math $i + 1)]
                end
            else if test "$argv[$i]" = --allow-cd
                set allow_cd 1
            else
                # Check if there is another argument after the current one
                if test (count $argv) -ge (math $i + 1)
                    set path (echo $argv[(math $i + 1)] | sed 's:/*$::')
                end
            end
        end
    end

    set -l selected_directory

    set selected_directory (fd . $path --min-depth 1 --type d --max-depth "$recursive_depth"  | fzf --prompt=(_fzf_preview_name $prompt_name))

    if test -n "$selected_directory"
        if test -n "$allow_cd"
            cd $selected_directory
        else
            commandline --current-token --replace -- (string escape -- $selected_directory)
        end
    end

    commandline --function repaint
end
