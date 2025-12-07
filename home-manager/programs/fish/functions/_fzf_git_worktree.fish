function _fzf_git_worktree --description="fzf git worktree picker"
    # Get all worktrees sorted by most recent commit
    set -l worktrees (for wt in (git worktree list 2>/dev/null | awk '{print $1}'); echo (git -C $wt log -1 --format=%ct 2>/dev/null; or echo 0)" $wt"; end | sort -rn | awk '{print $2}')

    if test -z "$worktrees"
        echo "No worktrees found (not a git repository?)"
        return 1
    end

    set -l selected_worktree (printf '%s\n' $worktrees | fzf --prompt=(_fzf_preview_name "Worktree") --preview='echo "Last commit: $(git -C {} log -1 --format="%cr" 2>/dev/null)"; echo ""; git -C {} log --oneline --color=always -n 10; echo ""; git -C {} status --short' --preview-window right:50%)

    if test -n "$selected_worktree"
        cd $selected_worktree
    end

    commandline --function repaint
end
