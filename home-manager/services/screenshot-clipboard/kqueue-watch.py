import os
import select
import subprocess
import sys

O_EVTONLY = 0x8000

desktop = os.path.expanduser("~/Desktop")
command = sys.argv[1:]

fd = os.open(desktop, os.O_RDONLY | O_EVTONLY)
kq = select.kqueue()
kq.control(
    [
        select.kevent(
            fd,
            filter=select.KQ_FILTER_VNODE,
            flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR,
            fflags=select.KQ_NOTE_WRITE
            | select.KQ_NOTE_DELETE
            | select.KQ_NOTE_RENAME
            | select.KQ_NOTE_REVOKE,
        )
    ],
    0,
)

print(f"Watching {desktop} for screenshots...", flush=True)

while True:
    for event in kq.control(None, 1):
        # The watched fd no longer points at ~/Desktop; exit so launchd
        # restarts the watcher on the new directory.
        if event.fflags & ~select.KQ_NOTE_WRITE:
            sys.exit(1)
        subprocess.run(command)
