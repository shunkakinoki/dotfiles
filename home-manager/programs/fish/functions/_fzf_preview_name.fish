function _fzf_preview_name --description="fzf preview name"
    set prompt_arrow ' '
    if test -n $argv
        echo "$argv $prompt_arrow"
    else
        echo "Search $prompt_arrow"
    end
end
