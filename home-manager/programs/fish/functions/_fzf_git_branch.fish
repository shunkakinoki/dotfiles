function _fzf_git_branch --description="fzf git branch picker"
    # Get all branches sorted by most recent commit, remove leading whitespace and asterisk, deduplicate
    set -l branches (git branch -a --sort=-committerdate 2>/dev/null | sed 's/^[ *]*//' | sed 's|remotes/origin/||' | grep -v '^HEAD' | awk '!seen[$0]++')

    if test -z "$branches"
        echo "No branches found (not a git repository?)"
        return 1
    end

    set -l selected_branch (printf '%s\n' $branches | fzf --prompt=(_fzf_preview_name "Branch") --preview='git log --oneline --color=always -n 10 {}' --preview-window right:50%)

    if test -n "$selected_branch"
        git checkout $selected_branch
    end

    commandline --function repaint
end
