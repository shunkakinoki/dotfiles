import importlib.util
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "home-manager/services/openclaw/snapshot-cache-cleanup.py"
)
SPEC = importlib.util.spec_from_file_location("snapshot_cache_cleanup", SCRIPT)
cleanup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cleanup)


class SnapshotCacheCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "cache"
        self.root.mkdir()
        self.proc = Path(self.temp.name) / "proc"
        self.proc.mkdir()
        self.old = time.time() - cleanup.MIN_AGE_SECONDS - 60

    def snapshot(self, outer_pid, inner_pid, *, extra=None, old=True):
        outer = self.root / f"openclaw-sqlite-readonly-{outer_pid}-AbC123"
        inner = outer / f"openclaw-sqlite-readonly-{inner_pid}-XyZ789"
        inner.mkdir(parents=True)
        (inner / "database.sqlite").write_bytes(b"database")
        (inner / "first").write_bytes(b"journal")
        if extra:
            (inner / extra).write_bytes(b"unexpected")
        if old:
            os.utime(inner, (self.old, self.old))
            os.utime(outer, (self.old, self.old))
        return outer

    def run_cleanup(self, limit=3):
        with patch.object(cleanup.time, "sleep"):
            return cleanup.reclaim(self.root, self.proc, lambda: None, limit)

    def test_reclaims_only_inactive_known_snapshot_files(self):
        stale = self.snapshot(99999991, 99999992)
        active = self.snapshot(99999993, 99999994)
        (self.proc / "99999993").mkdir()
        active_child = self.snapshot(99999971, 99999972)
        (self.proc / "99999972").mkdir()
        unexpected = self.snapshot(99999995, 99999996, extra="other.txt")
        young = self.snapshot(99999997, 99999998, old=False)

        self.assertEqual(self.run_cleanup(), 1)
        self.assertFalse(stale.exists())
        self.assertTrue(active.exists())
        self.assertTrue(active_child.exists())
        self.assertTrue(unexpected.exists())
        self.assertTrue(young.exists())

    def test_stops_before_removing_another_snapshot_when_health_fails(self):
        first = self.snapshot(99999981, 99999982)
        second = self.snapshot(99999983, 99999984)
        os.utime(first, (self.old - 10, self.old - 10))
        checks = iter((None, None, RuntimeError("unhealthy")))

        def healthcheck():
            result = next(checks)
            if result:
                raise result

        with patch.object(cleanup.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "unhealthy"):
                cleanup.reclaim(self.root, self.proc, healthcheck)
        self.assertFalse(first.exists())
        self.assertTrue(second.exists())


if __name__ == "__main__":
    unittest.main()
