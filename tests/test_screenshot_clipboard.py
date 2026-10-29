"""Exercise watcher failure and readiness across the macOS kqueue boundary."""

import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


WATCHER = (
    Path(__file__).resolve().parents[1]
    / "home-manager/services/screenshot-clipboard/kqueue-watch.py"
)


class WatcherTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.ready = self.root / "screenshot-clipboard/ready-pid"
        self.queue = Mock()
        self.select = SimpleNamespace(
            kqueue=lambda: self.queue,
            kevent=Mock(),
            KQ_FILTER_VNODE=-4,
            KQ_EV_ADD=1,
            KQ_EV_CLEAR=32,
            KQ_NOTE_WRITE=2,
            KQ_NOTE_DELETE=1,
            KQ_NOTE_RENAME=32,
            KQ_NOTE_REVOKE=64,
        )

    def run_watcher(self, command):
        with (
            patch.dict(os.environ, XDG_STATE_HOME=str(self.root)),
            patch.dict(sys.modules, select=self.select),
            patch.object(sys, "argv", [str(WATCHER), "/bin/sh", "-c", command]),
            patch("os.open", return_value=123),
        ):
            runpy.run_path(str(WATCHER), run_name="__main__")

    def test_startup_copy_failure_never_publishes_readiness(self):
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_watcher("exit 7")
        self.assertFalse(self.ready.exists())

    def test_event_copy_failure_exits_for_launchd_to_restart(self):
        event = SimpleNamespace(fflags=self.select.KQ_NOTE_WRITE)
        self.queue.control.side_effect = [[], [event]]
        marker = self.root / "first-copy"
        command = f'if [ -f "{marker}" ]; then exit 7; fi; touch "{marker}"'
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_watcher(command)
        self.assertEqual(self.ready.read_text(), str(os.getpid()))

    def test_successful_startup_publishes_readiness_after_copy(self):
        def control(*args):
            if args[0] is None:
                self.assertEqual(self.ready.read_text(), str(os.getpid()))
                raise StopIteration
            self.assertFalse(self.ready.exists())
            return []

        self.queue.control.side_effect = control
        marker = self.root / "copied"
        with self.assertRaises(StopIteration):
            self.run_watcher(f'touch "{marker}"')
        self.assertTrue(marker.exists())


if __name__ == "__main__":
    unittest.main()
