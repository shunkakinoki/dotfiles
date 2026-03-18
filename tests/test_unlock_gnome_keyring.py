"""Tests for named-hosts/matic/unlock-gnome-keyring.py.

The script is loaded by stripping the @python3@ placeholder shebang and
exec-ing the module body, so we can test the unlock() function directly
without spawning a subprocess.
"""

import os
import stat
import struct
import types
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

SCRIPT = Path(__file__).parent.parent / "named-hosts/matic/unlock-gnome-keyring.py"


def _load_module() -> types.ModuleType:
    """Import the script as a module, skipping its top-level side-effects.

    Loads only the imports and function definitions; stops before the module-level
    execution block (pw = sys.stdin.read() ... sys.exit()).
    """
    source = SCRIPT.read_text()
    lines = source.splitlines(keepends=True)
    # Strip the @python3@ shebang
    if lines and lines[0].startswith("#!"):
        lines = lines[1:]

    # Keep only lines up to (but not including) the module-level execution block
    definition_lines = []
    for line in lines:
        if line.startswith("pw = sys.stdin"):
            break
        definition_lines.append(line)

    code = "".join(definition_lines)
    mod = types.ModuleType("unlock_gnome_keyring")
    exec(compile(code, str(SCRIPT), "exec"), mod.__dict__)  # noqa: S102
    return mod


_mod = _load_module()
unlock = _mod.unlock


class TestUnlockProtocol(unittest.TestCase):
    """Tests for the unlock() socket protocol function."""

    def _make_stat(self, uid: int, is_sock: bool = True) -> MagicMock:
        st = MagicMock()
        st.st_uid = uid
        st.st_mode = stat.S_IFSOCK if is_sock else stat.S_IFREG
        return st

    def _make_socket(self, result: int) -> MagicMock:
        resp = struct.pack(">II", 8, result)
        sock = MagicMock()
        sock.__enter__ = lambda s: s
        sock.__exit__ = MagicMock(return_value=False)
        sock.recv.return_value = resp
        return sock

    @patch("socket.socket")
    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_unlock_ok(self, mock_uid, mock_lstat, mock_socket_cls):
        mock_lstat.return_value = self._make_stat(uid=1000)
        sock = self._make_socket(result=0)
        mock_socket_cls.return_value = sock

        result = unlock("correct-password")

        self.assertEqual(result, 0)
        sock.connect.assert_called_once()
        sock.sendall.assert_called()

    @patch("socket.socket")
    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_unlock_denied(self, mock_uid, mock_lstat, mock_socket_cls):
        mock_lstat.return_value = self._make_stat(uid=1000)
        sock = self._make_socket(result=1)
        mock_socket_cls.return_value = sock

        result = unlock("wrong-password")

        self.assertEqual(result, 1)

    @patch("socket.socket")
    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_unlock_no_daemon(self, mock_uid, mock_lstat, mock_socket_cls):
        mock_lstat.return_value = self._make_stat(uid=1000)
        sock = self._make_socket(result=3)
        mock_socket_cls.return_value = sock

        result = unlock("any-password")

        self.assertEqual(result, 3)

    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_bad_socket_wrong_owner(self, mock_uid, mock_lstat):
        mock_lstat.return_value = self._make_stat(uid=9999)

        with self.assertRaises(RuntimeError, msg="bad socket"):
            unlock("pw")

    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_bad_socket_not_a_socket(self, mock_uid, mock_lstat):
        mock_lstat.return_value = self._make_stat(uid=1000, is_sock=False)

        with self.assertRaises(RuntimeError, msg="bad socket"):
            unlock("pw")

    @patch("socket.socket")
    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_uses_xdg_runtime_dir(self, mock_uid, mock_lstat, mock_socket_cls):
        mock_lstat.return_value = self._make_stat(uid=1000)
        sock = self._make_socket(result=0)
        mock_socket_cls.return_value = sock

        with patch.dict(os.environ, {"XDG_RUNTIME_DIR": "/run/user/1000"}):
            unlock("pw")

        mock_lstat.assert_called_with("/run/user/1000/keyring/control")

    @patch("socket.socket")
    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_packet_structure(self, mock_uid, mock_lstat, mock_socket_cls):
        """Verify the protocol packet layout: oplen, op=1, pwlen, password."""
        mock_lstat.return_value = self._make_stat(uid=1000)
        sock = self._make_socket(result=0)
        mock_socket_cls.return_value = sock

        unlock("hello")

        # sendall called at least twice: once for \x00, once for the packet
        calls = sock.sendall.call_args_list
        self.assertGreaterEqual(len(calls), 2)
        self.assertEqual(calls[0][0][0], b"\x00")

        pkt = calls[1][0][0]
        pw = b"hello"
        expected_oplen = 8 + 4 + len(pw)
        oplen, op = struct.unpack(">II", pkt[:8])
        pwlen = struct.unpack(">I", pkt[8:12])[0]

        self.assertEqual(oplen, expected_oplen)
        self.assertEqual(op, 1)
        self.assertEqual(pwlen, len(pw))
        self.assertEqual(pkt[12:], pw)

    @patch("socket.socket")
    @patch("os.lstat")
    @patch("os.getuid", return_value=1000)
    def test_daemon_closes_connection_raises(
        self, mock_uid, mock_lstat, mock_socket_cls
    ):
        mock_lstat.return_value = self._make_stat(uid=1000)
        sock = MagicMock()
        sock.__enter__ = lambda s: s
        sock.__exit__ = MagicMock(return_value=False)
        sock.recv.return_value = b""  # simulate closed connection
        mock_socket_cls.return_value = sock

        with self.assertRaises(RuntimeError, msg="daemon closed connection"):
            unlock("pw")


if __name__ == "__main__":
    unittest.main()
