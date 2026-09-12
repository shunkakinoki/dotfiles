"""Serialize hook uploads, retaining coalesced events until their unit finishes."""

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

SLOTS = ("start", "progress", "end")
SERVICE = "traces-agent-uploads.service"


def session_identity(payload, arguments):
    agent = None
    for index, argument in enumerate(arguments):
        if argument == "--agent" and index + 1 < len(arguments):
            agent = arguments[index + 1]
        elif argument.startswith("--agent="):
            agent = argument.removeprefix("--agent=")
    # Native hook formats, as consumed by traces' agent adapters.
    fields = {
        "codex": ("id", "session_id", "sessionId"),
        "cursor": ("conversation_id", "session_id", "sessionId"),
        "antigravity": ("conversationId", "conversation_id", "session_id", "sessionId"),
        "openclaw": ("sessionKey", "session_id", "sessionId"),
    }.get(agent, ("session_id", "sessionId"))
    session = next((payload[name] for name in fields if payload.get(name)), None)
    return agent, session if isinstance(session, str) else None


class Queue:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)

    @contextlib.contextmanager
    def lock(self, name="queue.lock", blocking=True):
        descriptor = os.open(self.directory / name, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            flags = fcntl.LOCK_EX | (0 if blocking else fcntl.LOCK_NB)
            fcntl.flock(descriptor, flags)
            yield
        finally:
            os.close(descriptor)

    def write(self, path, value):
        temporary = path.with_suffix(".tmp")
        descriptor = os.open(temporary, os.O_CREAT | os.O_WRONLY | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, "w") as output:
            json.dump(value, output)
        os.replace(temporary, path)

    def enqueue(self, event, arguments, payload, binary, cwd, environment=None):
        slot = {
            "session-start": "start",
            "prompt-submitted": "progress",
            "agent-done": "progress",
            "session-end": "end",
        }[event]
        parsed = json.loads(payload)
        if not isinstance(parsed, dict):
            raise ValueError("Trace hook payload must be an object")
        _, session = session_identity(parsed, arguments)
        # Never coalesce unrelated native payloads without a session identity.
        identity = session if isinstance(session, str) else uuid.uuid4().hex
        key = hashlib.sha256(
            json.dumps([cwd, arguments, identity]).encode()
        ).hexdigest()
        path = self.directory / (key + ".json")
        with self.lock():
            record = json.loads(path.read_text()) if path.exists() else {}
            if slot != "end" and "end" in record:
                return
            trace_id = record.get(slot, {}).get("trace_id")
            record[slot] = {
                "id": uuid.uuid4().hex,
                "event": event,
                "arguments": arguments,
                "payload": payload,
                "binary": binary,
                "cwd": cwd,
                "environment": environment or {},
                "created": time.time(),
                "retry_at": 0,
                "failures": 0,
            }
            if slot == "end" and trace_id:
                record[slot]["trace_id"] = trace_id
            self.write(path, record)

    def next_event(self):
        candidates = []
        # Atomic replacements let the sole drainer scan without blocking hooks.
        # finish() checks the event identity again before acknowledging it.
        for path in self.directory.glob("*.json"):
            record = json.loads(path.read_text())
            for slot in SLOTS:
                if slot not in record:
                    continue
                event = record[slot]
                if event["retry_at"] <= time.time():
                    candidates.append((path, slot, event))
                # Registration/progress must finish before session-end.
                break
        return min(candidates, key=lambda item: item[2]["created"], default=None)

    def finish(self, path, slot, event, succeeded):
        with self.lock():
            record = json.loads(path.read_text())
            if record.get(slot, {}).get("id") != event["id"]:
                return  # A newer event arrived during this upload.
            if succeeded:
                del record[slot]
            else:
                event["failures"] += 1
                event["retry_at"] = time.time() + min(300, 30 * event["failures"])
                record[slot] = event
            if record:
                self.write(path, record)
            else:
                path.unlink()

    def drain(self, run, prepare=None):
        try:
            with self.lock("worker.lock", blocking=False):
                while candidate := self.next_event():
                    path, slot, event = candidate
                    try:
                        if slot == "end" and prepare:
                            prepare(event)
                            with self.lock():
                                record = json.loads(path.read_text())
                                if record.get(slot, {}).get("id") != event["id"]:
                                    continue
                                record[slot] = event
                                self.write(path, record)
                        succeeded = run(event)
                    except (OSError, subprocess.SubprocessError, ValueError, KeyError):
                        succeeded = False
                    self.finish(path, slot, event, succeeded)
        except BlockingIOError:
            return  # Another drainer retains the slot through child completion.


def prepare_final(event):
    agent, session = session_identity(json.loads(event["payload"]), event["arguments"])
    if not agent or not session:
        return
    result = subprocess.run(
        ["git", "rev-parse", "--absolute-git-dir"],
        cwd=event["cwd"],
        capture_output=True,
        text=True,
        timeout=5,
        check=True,
        env=os.environ | event["environment"],
    )
    active = Path(result.stdout.strip()) / "traces-active.json"
    try:
        sessions = json.loads(active.read_text())["sessions"]
    except FileNotFoundError:
        sessions = []
    registered = next(
        (
            item.get("traceId")
            for item in sessions
            if item.get("agentId") == agent and item.get("agentSessionId") == session
        ),
        None,
    )
    if registered:
        event["trace_id"] = registered
    # A timed-out final hook may already have removed its registration. Keep
    # the upstream-resolved ID on disk before starting that first final hook.
    event["share_retry"] = not registered and bool(event.get("trace_id"))


def run_hook(event):
    # ExitType=cgroup includes the uploader detached by `traces hook agent`.
    # BindsTo also stops it if the queue service crashes or is stopped.
    environment = os.environ | event["environment"]
    environment["TRACES_DISABLE_AUTOUPDATE"] = "1"
    arguments = ["hook", "agent", event["event"], *event["arguments"]]
    if event.get("share_retry"):
        arguments = [
            "share",
            "--trace-id",
            event["trace_id"],
            "--source",
            "agent_hook",
            "--json",
        ]
    command = [
        "systemd-run",
        "--user",
        "--quiet",
        "--wait",
        "--pipe",
        "--collect",
        "--service-type=exec",
        "--expand-environment=no",
        # A single unit name also prevents overlap after a drainer crash.
        "--unit=traces-agent-upload",
        "--description=Upload agent trace",
        "--slice=traces-uploads.slice",
        "--property=ExitType=cgroup",
        "--property=RuntimeMaxSec=900",
        "--property=TimeoutStopSec=10",
        "--property=KillMode=control-group",
        "--property=BindsTo=" + SERVICE,
        "--property=After=" + SERVICE,
        *["--setenv=" + name for name in event["environment"]],
        "--setenv=TRACES_DISABLE_AUTOUPDATE",
        "--working-directory=" + event["cwd"],
        "--",
        event["binary"],
        *arguments,
    ]
    result = subprocess.run(
        command,
        input="" if event.get("share_retry") else event["payload"],
        text=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=environment,
        check=False,
    )
    if result.returncode:
        print("Trace hook failed or timed out; retaining queued event", file=sys.stderr)
    return result.returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("operation", choices=("enqueue", "drain"))
    parser.add_argument("event", nargs="?")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    queue = Queue(args.state_dir)
    if args.operation == "drain":
        queue.drain(run_hook, prepare_final)
        return
    binary = shutil.which(os.environ.get("TRACES_BIN", "traces"))
    if not binary:
        return
    payload = sys.stdin.read(1_048_577)
    if len(payload.encode()) > 1_048_576:
        raise ValueError("Trace hook payload exceeds 1 MiB")
    # Preserve trace routing/auth overrides without putting their values in
    # process arguments. The private queue is removed after hook completion.
    environment = {
        name: value
        for name, value in os.environ.items()
        if name.startswith("TRACES_")
        or name
        in {
            "HOME",
            "PATH",
            "XDG_CONFIG_HOME",
            "XDG_DATA_HOME",
            "XDG_CACHE_HOME",
            "XDG_STATE_HOME",
        }
    }
    queue.enqueue(args.event, args.arguments, payload, binary, os.getcwd(), environment)
    try:
        subprocess.run(
            ["systemctl", "--user", "start", "--no-block", SERVICE],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        pass  # The timer retries a failed wakeup without another agent event.


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        # Do not include the payload or command arguments in hook diagnostics.
        print(
            "Trace upload queue unavailable: " + type(error).__name__, file=sys.stderr
        )
        sys.exit(1)
