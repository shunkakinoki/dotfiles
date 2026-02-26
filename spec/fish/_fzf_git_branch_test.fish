set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fzf_git_branch.fish

function git; end
function commandline; end
function fzf; end

@test "no branches prints error" (string match -q "*No branches found*" (_fzf_git_branch 2>/dev/null); echo $status) = 0
@test "no branches returns 1" (_fzf_git_branch >/dev/null 2>/dev/null; echo $status) = 1
