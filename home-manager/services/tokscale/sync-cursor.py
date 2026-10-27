#!/usr/bin/env python3
"""Bootstrap large Cursor histories in date chunks; keep native incremental sync."""

import argparse
import concurrent.futures
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid
from pathlib import Path

ENDPOINT = "https://cursor.com/api/dashboard/get-filtered-usage-events"
PAGE_SIZE = 500
CHUNK_EVENTS = 25000
MAX_PAGE_BYTES = 4 * 1024 * 1024


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def config_dir():
    return Path(
        os.environ.get("TOKSCALE_CONFIG_DIR")
        or Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
        / "tokscale"
    )


def cache_path(config, store, account):
    suffix = hashlib.sha256(account.encode()).hexdigest()
    filename = (
        "usage.json"
        if account == store["activeAccountId"]
        else f"usage.account-{suffix}.json"
    )
    return config / "cursor-cache" / filename


def cache_is_owned(path, account):
    # Tokscale verifies these bounded header/footer regions before trusting a
    # cache's incremental watermark. Never borrow another account's history.
    try:
        with path.open("rb") as source:
            prefix = source.read(1024).decode(errors="ignore")
            source.seek(max(0, path.stat().st_size - 1024))
            suffix = source.read().decode(errors="ignore")
        if not prefix.startswith('{"_owner":'):
            return False
        decoder = json.JSONDecoder()
        header, end = decoder.raw_decode(prefix[len('{"_owner":') :])
        if prefix[len('{"_owner":') + end] != ",":
            return False
        footer = json.loads(suffix.rsplit(',"zzTokscaleOwner":', 1)[1][:-1])
        return (
            header["version"] == footer["version"] == 1
            and header["generation"] == footer["generation"]
            and header["ownerHash"] == hashlib.sha256(account.encode()).hexdigest()
        )
    except (OSError, ValueError, KeyError, IndexError, TypeError):
        return False


class Bootstrap:
    def __init__(self, config, store, account):
        self.config = config
        self.account = account
        self.token = store["accounts"][account]["sessionToken"]
        self.destination = cache_path(config, store, account)
        self.end = int(time.time() * 1000)

    def page(self, start, end, page=1):
        body = encode(
            {
                "startDate": str(start),
                "endDate": str(end),
                "page": page,
                "pageSize": PAGE_SIZE,
            }
        ).encode()
        request = urllib.request.Request(
            ENDPOINT,
            data=body,
            headers={
                "Content-Type": "application/json",
                "Origin": "https://cursor.com",
                "Referer": "https://cursor.com/settings",
                "User-Agent": "Mozilla/5.0",
                "Cookie": "WorkosCursorSessionToken=" + self.token,
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read(MAX_PAGE_BYTES + 1)
        if len(raw) > MAX_PAGE_BYTES:
            raise ValueError("Cursor page exceeds the bounded response size")
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("Unexpected Cursor response shape")
        rows = result["usageEventsDisplay"]
        total = result["totalUsageEventsCount"]
        if not isinstance(rows, list) or not isinstance(total, int) or total < 0:
            raise ValueError("Unexpected Cursor response shape")
        if any(not start <= int(row["timestamp"]) <= end for row in rows):
            raise ValueError("Cursor returned events outside the requested date range")
        return total, rows

    def partition(self, start, end, initial):
        total, rows = initial
        if total <= CHUNK_EVENTS:
            return [(start, end, total, rows)] if total else []
        if start == end:
            raise ValueError("Too many Cursor events at a single timestamp")
        midpoint = (start + end) // 2
        left = self.page(start, midpoint)
        right = self.page(midpoint + 1, end)
        if left[0] + right[0] != total:
            raise ValueError("Cursor date-range counts do not add up")
        return self.partition(start, midpoint, left) + self.partition(
            midpoint + 1, end, right
        )

    def download(self, chunk, directory):
        start, end, expected, rows = chunk
        path = directory / f"{start}-{end}.jsonl"
        completed = 0
        seen_ids = set()
        page = 1
        with path.open("x") as output:
            while True:
                if not rows:
                    raise ValueError("Empty Cursor page before the advertised total")
                for row in rows:
                    event_id = row.get("usageEventId")
                    if event_id:
                        if event_id in seen_ids:
                            raise ValueError("Repeated Cursor event across pages")
                        seen_ids.add(event_id)
                    output.write(encode(row) + "\n")
                completed += len(rows)
                if completed == expected:
                    break
                if completed > expected or page >= 500:
                    raise ValueError("Cursor chunk exceeded its event or page limit")
                page += 1
                total, rows = self.page(start, end, page)
                if total != expected:
                    raise ValueError("Cursor chunk count changed during download")
        print(f"Cursor chunk verified: {completed} events", flush=True)
        return start, path, completed

    def install(self, completed, expected, directory):
        if sum(item[2] for item in completed) != expected:
            raise ValueError("Cursor chunks do not cover the full account")
        generation = str(uuid.uuid4())
        header = {
            "version": 1,
            "ownerHash": hashlib.sha256(self.account.encode()).hexdigest(),
            "generation": generation,
        }
        temporary = directory / "usage.json"
        written = 0
        with temporary.open("x") as output:
            output.write('{"_owner":' + encode(header))
            output.write(
                ',"_tokscale":' + encode({"version": 1, "accountId": self.account})
            )
            output.write(f',"totalUsageEventsCount":{expected},"usageEventsDisplay":[')
            for _, path, count in sorted(completed):
                observed = 0
                with path.open() as source:
                    for line in source:
                        output.write(("," if written else "") + line.rstrip("\n"))
                        written += 1
                        observed += 1
                if observed != count:
                    raise ValueError("Saved Cursor chunk count does not match")
            output.write(
                '],"zzTokscaleOwner":'
                + encode({"version": 1, "generation": generation})
                + "}"
            )
            output.flush()
            os.fsync(output.fileno())
        data = json.loads(temporary.read_text())
        if len(data["usageEventsDisplay"]) != expected or written != expected:
            raise ValueError("Combined Cursor cache failed count verification")
        del data
        current = json.loads((self.config / "cursor-credentials.json").read_text())
        if (
            self.account not in current["accounts"]
            or cache_path(self.config, current, self.account) != self.destination
        ):
            raise ValueError("Cursor account changed during download")
        if self.destination.exists():
            archive = self.destination.parent / "archive"
            archive.mkdir(mode=0o700, exist_ok=True)
            backup = archive / f"{self.destination.stem}-{generation}.json"
            shutil.copy2(self.destination, backup)
            backup.chmod(0o600)
        os.replace(temporary, self.destination)
        print(f"Cursor bootstrap complete: {expected} events", flush=True)

    def execute(self):
        self.destination.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        initial = self.page(0, self.end)
        expected, first = initial
        if expected:
            if not first:
                raise ValueError("Cursor returned no first page for a nonempty account")
            # The API can clamp pageSize; use the observed yield for the last page.
            total, last = self.page(0, self.end, math.ceil(expected / len(first)))
            if total != expected or not last:
                raise ValueError("Cannot verify the oldest Cursor history boundary")
            oldest = min(int(row["timestamp"]) for row in last)
            bounded = self.page(oldest, self.end)
            if bounded[0] != expected:
                raise ValueError("Cursor date range does not cover the full account")
            chunks = self.partition(oldest, self.end, bounded)
        else:
            chunks = []
        with tempfile.TemporaryDirectory(
            prefix=".cursor-bootstrap-", dir=self.destination.parent
        ) as scratch:
            directory = Path(scratch)
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as workers:
                completed = list(
                    workers.map(lambda chunk: self.download(chunk, directory), chunks)
                )
            self.install(completed, expected, directory)


def native_sync(binary):
    result = subprocess.run(
        ["bun", str(binary), "--no-spinner", "cursor", "sync", "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    try:
        data = json.loads(result.stdout)
    except ValueError as error:
        raise RuntimeError("Tokscale Cursor sync did not return valid JSON") from error
    if not isinstance(data, dict) or (result.returncode and data.get("synced")):
        raise RuntimeError("Tokscale Cursor sync exited unsuccessfully")
    return data


def sync(config, binary):
    credentials = config / "cursor-credentials.json"
    if not credentials.exists():
        print("No saved Cursor credentials; skipping Cursor sync")
        return
    store = json.loads(credentials.read_text())
    accounts = store["accounts"]
    for account in accounts:
        if not cache_is_owned(cache_path(config, store, account), account):
            Bootstrap(config, store, account).execute()
    if not accounts:
        print("No saved Cursor accounts; skipping Cursor sync")
        return
    result = native_sync(binary)
    if not result.get("synced"):
        error = result.get("error") or ""
        if "byte limit" not in error and "-page fetch limit" not in error:
            raise RuntimeError(
                "Cursor sync failed; check 'tokscale cursor status' "
                "and renew login if needed"
            )
        # A long offline interval can also exceed native incremental-download
        # limits. Rebuild through bounded date ranges, preserving the old cache.
        for account in accounts:
            Bootstrap(config, store, account).execute()
        result = native_sync(binary)
        if not result.get("synced"):
            raise RuntimeError("Native Cursor sync failed after chunked bootstrap")
    print(encode({"synced": True, "rows": result.get("rows", 0)}))


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tokscale_bin", type=Path)
    args = parser.parse_args()
    try:
        sync(config_dir(), args.tokscale_bin)
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print(f"Cursor sync incomplete: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
