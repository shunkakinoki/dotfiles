set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fzf_shell_history.fish

function commandline; end
function fzf; end
function history; end

@test "sources and exits cleanly" (_fzf_shell_history; echo done) = done
