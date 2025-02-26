function _fzf_cmd_history --description="fzf command history"
    set -l search_term (commandline --current-token)
    set -l prompt_name 'Command History'
    set -l allow_execute

    if test (count $argv) -gt 0
        for i in (seq (count $argv))
            if test "$argv[$i]" = --prompt-name
                set prompt_name $argv[(math $i + 1)]
            else if test "$argv[$i]" = --allow-execute
                set allow_execute 1
            end
        end
    end

    set -l selected_command (history | fzf --prompt=(_fzf_preview_name $prompt_name) --no-color)

    if test -n "$selected_command"
        # commandline --current-token --replace -- (string escape -- $selected_command)
        commandline --current-token --replace -- $selected_command
    end

    if test -n "$allow_execute"
        commandline --function execute
    end
end
