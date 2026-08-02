"""Moshi observer plugin for Hermes Agent, rendered by Nix."""

import json
import os
import subprocess
import threading
import uuid
from collections import defaultdict, deque
from concurrent.futures import ThreadPoolExecutor

HELPER = "@moshiHook@"
_pending = defaultdict(deque)
_pending_lock = threading.Lock()
_delivery = ThreadPoolExecutor(max_workers=1, thread_name_prefix="moshi-hooks")


def _deliver(payload):
    try:
        subprocess.run(
            [HELPER, "hermes-hook"],
            input=json.dumps(payload, ensure_ascii=False),
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=10,
            check=False,
        )
    except Exception:
        pass


def _send(event_name, session_id="", **extra):
    payload = {
        "hook_event_name": event_name,
        "session_id": str(session_id or extra.pop("session_key", "") or "hermes"),
        "cwd": os.getcwd(),
        **extra,
    }
    try:
        _delivery.submit(_deliver, payload)
    except RuntimeError:
        _deliver(payload)


def _session(primary="", kwargs=None):
    kwargs = kwargs or {}
    return str(kwargs.get("session_id") or primary or kwargs.get("task_id") or "hermes")


def _approval_key(session_key, command, pattern_key):
    return (str(session_key or ""), str(command or ""), str(pattern_key or ""))


def on_session_start(session_id="", model="", platform="", **kwargs):
    _send("SessionStart", _session(session_id, kwargs), model=model, platform=platform)


def on_pre_llm_call(session_id="", user_message="", model="", platform="", **kwargs):
    _send(
        "UserPromptSubmit",
        _session(session_id, kwargs),
        prompt=user_message,
        model=model,
        platform=platform,
    )


def on_post_llm_call(
    session_id="", assistant_response="", model="", platform="", **kwargs
):
    _send(
        "AgentEnd",
        _session(session_id, kwargs),
        last_assistant_message=assistant_response,
        model=model,
        platform=platform,
    )


def on_session_end(
    session_id="",
    completed=False,
    interrupted=False,
    model="",
    platform="",
    **kwargs,
):
    if interrupted or not completed:
        _send(
            "TurnInterrupted",
            _session(session_id, kwargs),
            interrupted=bool(interrupted),
            model=model,
            platform=platform,
        )


def on_session_finalize(session_id=None, platform="", **kwargs):
    if session_id:
        _send("SessionEnd", _session(session_id, kwargs), platform=platform)


def on_pre_tool_call(tool_name="", **kwargs):
    _send("PreToolUse", _session(kwargs=kwargs), tool_name=tool_name)


def on_post_tool_call(tool_name="", **kwargs):
    _send("PostToolUse", _session(kwargs=kwargs), tool_name=tool_name)


def on_pre_approval_request(
    command="",
    description="",
    pattern_key="",
    pattern_keys=None,
    session_key="",
    surface="",
    **kwargs,
):
    if surface != "cli":
        return
    action_id = uuid.uuid4().hex
    key = _approval_key(session_key, command, pattern_key)
    with _pending_lock:
        _pending[key].append(action_id)
    _send(
        "PermissionRequest",
        _session(session_key, kwargs),
        action_id=action_id,
        command=command,
        description=description,
        pattern_key=pattern_key,
        pattern_keys=pattern_keys or [],
        surface=surface,
    )


def on_post_approval_response(
    command="",
    description="",
    pattern_key="",
    pattern_keys=None,
    session_key="",
    surface="",
    choice="",
    **kwargs,
):
    if surface != "cli":
        return
    key = _approval_key(session_key, command, pattern_key)
    with _pending_lock:
        queue = _pending.get(key)
        action_id = queue.popleft() if queue else ""
        if queue is not None and not queue:
            _pending.pop(key, None)
    _send(
        "PermissionResolved",
        _session(session_key, kwargs),
        action_id=action_id,
        command=command,
        description=description,
        choice=choice,
        surface=surface,
    )


def register(ctx):
    ctx.register_hook("on_session_start", on_session_start)
    ctx.register_hook("pre_llm_call", on_pre_llm_call)
    ctx.register_hook("post_llm_call", on_post_llm_call)
    ctx.register_hook("on_session_end", on_session_end)
    ctx.register_hook("on_session_finalize", on_session_finalize)
    ctx.register_hook("pre_tool_call", on_pre_tool_call)
    ctx.register_hook("post_tool_call", on_post_tool_call)
    ctx.register_hook("pre_approval_request", on_pre_approval_request)
    ctx.register_hook("post_approval_response", on_post_approval_response)
