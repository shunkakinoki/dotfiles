set fn ../../home-manager/programs/fish/functions
source $fn/_fzf_git_worktree.fish

function git; end
function commandline; end
function fzf; end

@test "no worktrees prints error" (string match -q "*No worktrees found*" (_fzf_git_worktree 2>/dev/null); echo $status) = 0
@test "no worktrees returns 1" (_fzf_git_worktree >/dev/null 2>/dev/null; echo $status) = 1
