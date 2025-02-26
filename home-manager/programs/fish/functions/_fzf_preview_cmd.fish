function _fzf_preview_cmd --description="fzf preview cmd"
    if test -d $argv[1]
        cat $argv[1]
    else
        bat --color=always $argv[1]
    end
end
