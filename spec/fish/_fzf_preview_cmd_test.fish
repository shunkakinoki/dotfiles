set fn ../../home-manager/programs/fish/functions
source $fn/_fzf_preview_cmd.fish

set tmpdir (mktemp -d)
set tmpfile (mktemp)

set dir_log (mktemp)
set file_log (mktemp)

function cat; echo cat >> $dir_log; end
function bat; echo bat >> $file_log; end

_fzf_preview_cmd $tmpdir
_fzf_preview_cmd $tmpfile

@test "directory dispatches to cat" (grep -c "cat" $dir_log) -ge 1
@test "file dispatches to bat" (grep -c "bat" $file_log) -ge 1

rm -rf $tmpdir $tmpfile $dir_log $file_log
