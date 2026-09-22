#!/usr/bin/env python3
"""Pace removal of abandoned OpenClaw read-only SQLite snapshots."""

import os
import re
import stat
import time
import urllib.request

SNAPSHOT_NAME = re.compile(r"openclaw-sqlite-readonly-([0-9]+)-[A-Za-z0-9]+\Z")
SNAPSHOT_FILES = {
    "database.sqlite",
    "database.sqlite-wal",
    "database.sqlite-shm",
    "database.sqlite-journal",
    "first",
}
MIN_AGE_SECONDS = 6 * 60 * 60
MAX_FULL_IO_PSI = 55.0
MAX_PER_RUN = 3


def inactive(directory, now, proc_root="/proc"):
    match = SNAPSHOT_NAME.fullmatch(directory.name)
    if not match or not directory.is_dir(follow_symlinks=False):
        return False
    metadata = directory.stat(follow_symlinks=False)
    if metadata.st_uid != os.geteuid() or now - metadata.st_mtime < MIN_AGE_SECONDS:
        return False
    return not os.path.exists(os.path.join(proc_root, match.group(1)))


def snapshot_files(outer, now, proc_root="/proc"):
    if not inactive(outer, now, proc_root):
        return None
    children = list(os.scandir(outer.path))
    if len(children) != 1 or not inactive(children[0], now, proc_root):
        return None
    inner = children[0]
    files = list(os.scandir(inner.path))
    if not files or any(
        entry.name not in SNAPSHOT_FILES
        or not stat.S_ISREG(entry.stat(follow_symlinks=False).st_mode)
        or entry.stat(follow_symlinks=False).st_uid != os.geteuid()
        for entry in files
    ):
        return None
    return inner, files


def healthy():
    with open("/proc/pressure/io", encoding="ascii") as pressure:
        full = next(line for line in pressure if line.startswith("full "))
    match = re.search(r"avg10=([0-9.]+)", full)
    if match is None or float(match.group(1)) > MAX_FULL_IO_PSI:
        raise RuntimeError("root disk I/O pressure is too high for cache cleanup")
    with urllib.request.urlopen(
        "http://127.0.0.1:8317/management.html", timeout=3
    ) as response:
        if response.status != 200:
            raise RuntimeError(f"CLIProxy HTTP {response.status}")


def reclaim(root, proc_root="/proc", healthcheck=healthy, limit=MAX_PER_RUN):
    if not os.path.isdir(root):
        return 0
    healthcheck()
    now = time.time()
    with os.scandir(root) as entries:
        candidates = [entry for entry in entries if inactive(entry, now, proc_root)]
    candidates.sort(key=lambda entry: entry.stat(follow_symlinks=False).st_mtime)

    removed = 0
    apparent_bytes = 0
    for outer in candidates:
        if removed >= limit:
            break
        snapshot = snapshot_files(outer, time.time(), proc_root)
        if snapshot is None:
            continue
        healthcheck()
        inner, files = snapshot
        for entry in files:
            apparent_bytes += entry.stat(follow_symlinks=False).st_size
            os.unlink(entry.path)
        os.rmdir(inner.path)
        os.rmdir(outer.path)
        removed += 1
        if removed < limit:
            time.sleep(15)
    print(f"removed={removed} apparent_bytes={apparent_bytes}", flush=True)
    return removed


if __name__ == "__main__":
    cache_home = os.environ.get("XDG_CACHE_HOME")
    if not cache_home or not os.path.isabs(cache_home):
        cache_home = os.path.join(os.environ["HOME"], ".cache")
    reclaim(os.path.join(cache_home, "openclaw"))
