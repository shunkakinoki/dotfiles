"""Cursor bootstrap fixtures without external network or real credentials."""

import importlib.util
import json
import os
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

SOURCE = Path(__file__).parents[1] / "home-manager/services/tokscale/sync-cursor.py"
spec = importlib.util.spec_from_file_location("cursor_sync", SOURCE)
cursor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cursor)


@pytest.fixture
def fixture(tmp_path, monkeypatch):
    account = "fixture-account"
    token = "fixture-token-not-for-process-arguments"
    config = tmp_path / "tokscale"
    config.mkdir()
    store = {"activeAccountId": account, "accounts": {account: {"sessionToken": token}}}
    (config / "cursor-credentials.json").write_text(json.dumps(store))
    state = {
        "requests": [],
        "clamp": 2,
        "failure": None,
        "rows": [
            {"timestamp": str(t), "usageEventId": str(i), "model": "fixture-model"}
            for i, t in enumerate([1000, 2000, 2000, 3000, 4000, 5000, 5000, 6000])
        ],
    }

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            state["requests"].append((body, self.headers["Cookie"]))
            rows = [
                row
                for row in reversed(state["rows"])
                if int(body["startDate"])
                <= int(row["timestamp"])
                <= int(body["endDate"])
            ]
            size = min(body["pageSize"], state["clamp"])
            page = body["page"]
            selected = rows[(page - 1) * size : page * size]
            if state["failure"] == "empty-page" and page > 1:
                selected = []
            if state["failure"] == "duplicate" and page > 1:
                selected = rows[:size]
            total = len(rows)
            if state["failure"] == "wrong-total" and int(body["startDate"]) > 0:
                total += 1
            payload = json.dumps(
                {"totalUsageEventsCount": total, "usageEventsDisplay": selected}
            ).encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    monkeypatch.setattr(cursor, "ENDPOINT", f"http://127.0.0.1:{server.server_port}")
    monkeypatch.setattr(cursor, "PAGE_SIZE", 2)
    monkeypatch.setattr(cursor, "CHUNK_EVENTS", 3)
    original_init = cursor.Bootstrap.__init__

    def initialize(self, *args):
        original_init(self, *args)
        self.end = 10000

    monkeypatch.setattr(cursor.Bootstrap, "__init__", initialize)
    original_umask = os.umask(0o077)
    yield config, store, account, token, state
    os.umask(original_umask)
    server.shutdown()
    server.server_close()
    thread.join()


def test_large_history_splits_and_preserves_timestamp_boundaries(fixture):
    config, store, account, token, state = fixture
    cursor.Bootstrap(config, store, account).execute()
    path = cursor.cache_path(config, store, account)
    cached = json.loads(path.read_text())
    assert sorted(
        cached["usageEventsDisplay"], key=lambda row: row["usageEventId"]
    ) == (sorted(state["rows"], key=lambda row: row["usageEventId"]))
    assert cached["totalUsageEventsCount"] == len(state["rows"])
    assert cursor.cache_is_owned(path, account)
    assert path.stat().st_mode & 0o777 == 0o600
    assert all(
        cookie == f"WorkosCursorSessionToken={token}" for _, cookie in state["requests"]
    )
    assert not list(path.parent.glob(".cursor-bootstrap-*"))


def test_server_page_size_clamping_still_fetches_every_event(fixture):
    config, store, account, _, state = fixture
    state["clamp"] = 1
    cursor.Bootstrap(config, store, account).execute()
    cached = json.loads(cursor.cache_path(config, store, account).read_text())
    assert len(cached["usageEventsDisplay"]) == 8


@pytest.mark.parametrize("failure", ["empty-page", "duplicate", "wrong-total"])
def test_incomplete_download_never_replaces_previous_cache(fixture, failure):
    config, store, account, _, state = fixture
    path = cursor.cache_path(config, store, account)
    path.parent.mkdir()
    path.write_text("previous-cache")
    state["failure"] = failure
    with pytest.raises(ValueError):
        cursor.Bootstrap(config, store, account).execute()
    assert path.read_text() == "previous-cache"


def test_wrong_account_cache_is_archived_and_never_used_as_watermark(fixture):
    config, store, account, _, _ = fixture
    path = cursor.cache_path(config, store, account)
    path.parent.mkdir()
    path.write_text("unverified-owner-cache")
    assert not cursor.cache_is_owned(path, account)
    cursor.Bootstrap(config, store, account).execute()
    assert cursor.cache_is_owned(path, account)
    backups = list((path.parent / "archive").glob("*.json"))
    assert len(backups) == 1
    assert backups[0].read_text() == "unverified-owner-cache"


def test_warm_sync_uses_native_incremental_and_keeps_cookie_out_of_arguments(
    fixture, monkeypatch
):
    config, store, account, token, state = fixture
    cursor.Bootstrap(config, store, account).execute()
    state["requests"].clear()
    calls = []

    def native(args, **kwargs):
        calls.append((args, kwargs))
        return subprocess.CompletedProcess(
            args, 0, json.dumps({"synced": True, "rows": 8})
        )

    monkeypatch.setattr(cursor.subprocess, "run", native)
    cursor.sync(config, Path("fixture-cli.js"))
    assert not state["requests"]
    assert len(calls) == 1
    assert "--json" in calls[0][0]
    assert token not in str(calls)


def test_native_download_limit_triggers_chunk_rebuild(fixture, monkeypatch):
    config, store, account, _, state = fixture
    cursor.Bootstrap(config, store, account).execute()
    state["requests"].clear()
    replies = iter(
        [
            {"synced": False, "error": "Cursor JSON is over the byte limit"},
            {"synced": True, "rows": 8},
        ]
    )
    monkeypatch.setattr(cursor, "native_sync", lambda _binary: next(replies))
    cursor.sync(config, Path("fixture-cli.js"))
    assert state["requests"]
    assert cursor.cache_is_owned(cursor.cache_path(config, store, account), account)


def test_auth_failure_is_reported_without_replacing_cache(fixture, monkeypatch):
    config, store, account, _, state = fixture
    cursor.Bootstrap(config, store, account).execute()
    path = cursor.cache_path(config, store, account)
    previous = path.read_bytes()
    state["requests"].clear()
    monkeypatch.setattr(
        cursor, "native_sync", lambda _binary: {"synced": False, "error": "expired"}
    )
    with pytest.raises(RuntimeError, match="renew login"):
        cursor.sync(config, Path("fixture-cli.js"))
    assert path.read_bytes() == previous
    assert not state["requests"]


def test_secondary_account_names_do_not_collide(fixture):
    config, store, account, _, _ = fixture
    assert cursor.cache_path(config, store, "account/a") != cursor.cache_path(
        config, store, "account_a"
    )
    assert cursor.cache_path(config, store, account).name == "usage.json"
