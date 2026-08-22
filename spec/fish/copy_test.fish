set fn (status dirname)/../../home-manager/programs/fish/functions
source $fn/copy.fish

set tmpdir (mktemp -d)
mkdir -p $tmpdir/.local/scripts
set -x HOME $tmpdir

echo '#!/bin/sh
cat' >$tmpdir/.local/scripts/clipboard-copy
echo '#!/bin/sh
echo image:$1' >$tmpdir/.local/scripts/clipboard-copy-image
echo '#!/bin/sh
echo file:$1' >$tmpdir/.local/scripts/clipboard-copy-file
chmod +x $tmpdir/.local/scripts/clipboard-copy $tmpdir/.local/scripts/clipboard-copy-image $tmpdir/.local/scripts/clipboard-copy-file

@test "stdin goes to clipboard-copy" (echo hello | copy) = hello

touch $tmpdir/pic.png
@test "image file goes to clipboard-copy-image" (copy $tmpdir/pic.png) = "image:$tmpdir/pic.png"

touch $tmpdir/notes.txt
@test "text file goes to clipboard-copy-file" (copy $tmpdir/notes.txt) = "file:$tmpdir/notes.txt"

set joined (copy one two | string collect)
@test "args go to clipboard-copy as text" "$joined" = "one two"

mkdir -p $tmpdir/dir
copy $tmpdir/dir >/dev/null 2>&1
@test "directory is rejected" $status = 1

rm -rf $tmpdir
