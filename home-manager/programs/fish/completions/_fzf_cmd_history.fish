complete _fzf_cmd_history -n __fish_use_subcommand -l prompt-name -d 'Custom prompt name'
complete _fzf_cmd_history -n __fish_use_subcommand -l allow-execute -d 'Allow execution of selected command'

function _fzf_cmd_history_command_complete
    set -l options

    for option in (history)
        set options $options $option
    end

    echo $options
end

complete -c _fzf_cmd_history --arguments '(_fzf_cmd_history_command_complete)' -d 'Command to search in history'
