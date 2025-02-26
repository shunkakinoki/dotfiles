complete _fzf_file_picker -l show-hidden-files -r -d 'Show hidden files'
complete _fzf_file_picker -l prompt-name -r -d 'Custom prompt name for file selection'
complete _fzf_file_picker -l allow-open-in-editor -r -d 'Allow opening files in editor'

function _fzf_file_picker_path_complete
    set -l options

    if test "$show_hidden_files" = true
        for option in (fd . $path --type f --type d --hidden)
            set options $options (basename $option)
        end
    else
        for option in (fd . $path --type f --type d --exclude .git --exclude .gitignore 2>/dev/null)
            set options $options (basename $option)
        end
    end

    echo $options
end

complete -c _fzf_file_picker --arguments '(_fzf_file_picker_path_complete)' -d 'File or directory path'
