set fn ../../home-manager/programs/fish/functions
source $fn/_tsk_function.fish

function tmux; end
function fzf; end

@test "no sessions exits cleanly" (_tsk_function; echo done) = done
