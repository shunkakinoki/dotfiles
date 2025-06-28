function _fzf_ghq_picker --description="fzf ghq repository picker"
    set -l selected_repo (ghq list | fzf --prompt=(_fzf_preview_name "Repository") --preview 'ghq look {} --dry-run | head -1' --preview-window right:30%)
    
    if test -n "$selected_repo"
        cd (ghq root)/$selected_repo
    end
    
    commandline --function repaint
end