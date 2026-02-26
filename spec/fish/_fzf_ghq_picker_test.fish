set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fzf_ghq_picker.fish

function commandline; end
function fzf; end
function ghq; end

@test "no repo selected exits cleanly" (_fzf_ghq_picker; echo done) = done
