set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fzf_directory_picker.fish

function commandline; end
function fzf; end
function fd; end

@test "no selection exits cleanly" (_fzf_directory_picker; echo done) = done
