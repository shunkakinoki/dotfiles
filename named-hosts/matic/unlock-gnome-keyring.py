#!@python3@/bin/python3
# Speaks the gnome-keyring control socket protocol directly.
# gnome-keyring-daemon --unlock (v48) ignores GNOME_KEYRING_CONTROL
# and always starts a new instance, so we bypass it entirely.
#
# Protocol (all big-endian):
#   1. connect to $XDG_RUNTIME_DIR/keyring/control (UNIX stream)
#   2. send \x00 — daemon reads our UID via SO_PEERCRED
#   3. send [oplen:4][op=1:4][pwlen:4][password bytes]
#          where oplen = 8 + 4 + len(password)
#   4. read [8:4][result:4] — result 0 = OK
import os
import socket
import stat
import struct
import sys


def unlock(password):
    uid = os.getuid()
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")
    sock_path = os.path.join(xdg, "keyring", "control")
    st = os.lstat(sock_path)
    if not stat.S_ISSOCK(st.st_mode) or st.st_uid != uid:
        raise RuntimeError(f"bad socket: {sock_path}")
    pw = password.encode()
    oplen = 8 + 4 + len(pw)
    pkt = struct.pack(">II", oplen, 1) + struct.pack(">I", len(pw)) + pw
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(sock_path)
        s.sendall(b"\x00")
        s.sendall(pkt)
        resp = b""
        while len(resp) < 8:
            chunk = s.recv(8 - len(resp))
            if not chunk:
                raise RuntimeError(f"daemon closed connection after {len(resp)} bytes")
            resp += chunk
    _, result = struct.unpack(">II", resp)
    return result


pw = sys.stdin.read().rstrip("\n")
result = unlock(pw)
codes = {0: "OK", 1: "DENIED", 2: "FAILED", 3: "NO_DAEMON"}
print(f"gnome-keyring unlock: {codes.get(result, result)}", flush=True)
sys.exit(0 if result == 0 else 1)
