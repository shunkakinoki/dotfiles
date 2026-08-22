set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/paste.fish

set tmpdir (mktemp -d)
mkdir -p $tmpdir/.local/scripts
set -x HOME $tmpdir

printf '#!/bin/sh\necho pasted "$@"\n' >$tmpdir/.local/scripts/clipboard-paste
chmod +x $tmpdir/.local/scripts/clipboard-paste

@test "paste calls clipboard-paste" (paste) = pasted

@test "paste forwards args" (paste --no-newline) = "pasted --no-newline"

rm -rf $tmpdir
