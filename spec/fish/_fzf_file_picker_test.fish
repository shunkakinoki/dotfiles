set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/_fzf_file_picker.fish

function commandline; end
function fd; end
function fzf; end
function bat; end

@test "no selection exits cleanly" (_fzf_file_picker; echo done) = done

# ── EDITOR not set → error when opening in editor ────────
set -e EDITOR
function fzf; echo somefile; end

@test "missing EDITOR prints error" (string match -q "*EDITOR*is not set*" (_fzf_file_picker --allow-open-in-editor 2>&1); echo $status) = 0
@test "missing EDITOR returns 1" (_fzf_file_picker --allow-open-in-editor 2>/dev/null; echo $status) = 1
