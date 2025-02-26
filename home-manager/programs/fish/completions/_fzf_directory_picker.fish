complete _fzf_directory_picker -l recursive-depth -r -d 'Set the recursive depth for directory search'
complete _fzf_directory_picker -l prompt-name -r -d 'Custom prompt name for directory selection'
complete _fzf_directory_picker -l allow-cd -r -d 'Allow changing directory'

function _fzf_directory_picker_path_complete
    set -l options
    for option in (fd . $path --min-depth 1 --type d)
        set options $options (basename $option)
    end
    echo $options
end

complete -c _fzf_directory_picker --arguments '(_fzf_directory_picker_path_complete)' -d 'Directory path'
