"""Forward Hermes lifecycle events to the Traces CLI."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

AGENT_ID = "hermes"
TIMEOUT_SECONDS = 30


def _resolve_traces_bin() -> str | None:
    override = os.environ.get("TRACES_BIN")
    candidates = [
        Path(override) if override else None,
        Path.home() / ".bun/install/global/node_modules/.bin/traces",
        Path.home() / ".local/bin/traces",
    ]
    for candidate in candidates:
        if candidate and os.access(candidate, os.X_OK):
            return str(candidate)
    return shutil.which("traces")


def _resolve_cwd() -> str | None:
    """traces refuses to run outside a git repo and routes by working directory.

    The gateway runs from ~/.hermes, so a git-initialised workspace beneath it
    carries the folder share rule that decides the destination namespace.
    """
    workspace = os.environ.get("HERMES_WORKSPACE_DIR")
    candidates = [Path(workspace)] if workspace else []
    candidates += [Path.home() / ".hermes/workspace", Path.cwd()]
    for candidate in candidates:
        for directory in [candidate, *candidate.parents]:
            if (directory / ".git").exists():
                return str(candidate)
    return None


def _call_hook(event: str, session_id: str) -> None:
    binary = _resolve_traces_bin()
    cwd = _resolve_cwd()
    if not binary or not cwd or not session_id:
        return
    payload = json.dumps({"sessionKey": session_id, "session_id": session_id})
    try:
        proc = subprocess.Popen(
            [binary, "hook", "agent", event, "--agent", AGENT_ID],
            cwd=cwd,
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        proc.communicate(input=payload.encode(), timeout=TIMEOUT_SECONDS)
    except Exception:
        pass


def _session_id(obj: object) -> str:
    for attribute in ("session_id", "sessionId", "id"):
        value = getattr(obj, attribute, "")
        if value:
            return str(value)
    return ""


EVENTS = {
    "on_session_start": "session-start",
    "on_session_end": "session-end",
    "pre_llm_call": "prompt-submitted",
    "post_llm_call": "agent-done",
}


def register(ctx) -> None:
    for hook, event in EVENTS.items():

        def handler(obj, event=event):
            _call_hook(event, _session_id(obj))

        ctx.register_hook(hook, handler)
