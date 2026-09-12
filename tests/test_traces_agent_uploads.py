import importlib.util
import io
import json
import multiprocessing
import os
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "home-manager/services/traces-agent-uploads/queue.py"
)
SPEC = importlib.util.spec_from_file_location("traces_upload_queue", SCRIPT)
queue_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(queue_module)
Queue = queue_module.Queue


def enqueue_process(directory, session):
    Queue(directory).enqueue(
        "session-end",
        ["--agent", "codex"],
        json.dumps({"session_id": session}),
        "/bin/true",
        "/tmp",
    )


class TraceUploadQueueTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.queue = Queue(Path(self.temporary.name) / "queue")

    def enqueue(self, event, session="session-a", **payload):
        self.queue.enqueue(
            event,
            ["--agent", "codex"],
            json.dumps({"session_id": session, **payload}),
            "/bin/true",
            "/tmp",
        )

    def test_progress_coalesces_but_registration_and_end_survive(self):
        self.enqueue("session-start")
        self.enqueue("prompt-submitted", generation=1)
        self.enqueue("agent-done", generation=2)
        self.enqueue("session-end")
        self.enqueue("agent-done", generation=3)
        observed = []
        self.queue.drain(lambda event: observed.append(event) or True)
        self.assertEqual(
            [event["event"] for event in observed],
            ["session-start", "agent-done", "session-end"],
        )
        self.assertEqual(json.loads(observed[1]["payload"])["generation"], 2)
        self.assertIsNone(self.queue.next_event())

    def test_new_event_during_upload_is_not_removed_by_old_completion(self):
        self.enqueue("prompt-submitted", generation=1)
        path, slot, event = self.queue.next_event()
        self.enqueue("agent-done", generation=2)
        self.enqueue("session-end")
        self.queue.finish(path, slot, event, True)
        observed = []
        self.queue.drain(lambda item: observed.append(item) or True)
        self.assertEqual(len(observed), 2)
        self.assertEqual(json.loads(observed[0]["payload"])["generation"], 2)
        self.assertEqual(observed[1]["event"], "session-end")

    def test_final_event_waits_for_active_upload_and_second_drainer_exits(self):
        self.enqueue("agent-done")
        started = threading.Event()
        release = threading.Event()
        observed = []

        def run(event):
            observed.append(event["event"])
            if event["event"] == "agent-done":
                started.set()
                self.assertTrue(release.wait(5))
            return True

        worker = threading.Thread(target=self.queue.drain, args=(run,))
        worker.start()
        try:
            self.assertTrue(started.wait(5))
            self.enqueue("session-end")
            competing = []
            Queue(self.queue.directory).drain(
                lambda event: competing.append(event) or True
            )
            self.assertEqual(competing, [])
            self.assertEqual(observed, ["agent-done"])
        finally:
            release.set()
            worker.join(5)
        self.assertFalse(worker.is_alive())
        self.assertEqual(observed, ["agent-done", "session-end"])

    def test_concurrent_final_events_are_retained_and_private(self):
        context = multiprocessing.get_context("fork")
        processes = [
            context.Process(
                target=enqueue_process,
                args=(self.queue.directory, "session-" + str(index)),
            )
            for index in range(12)
        ]
        for process in processes:
            process.start()
        for process in processes:
            process.join(5)
            self.assertEqual(process.exitcode, 0)
        records = list(self.queue.directory.glob("*.json"))
        self.assertEqual(len(records), 12)
        self.assertEqual(os.stat(self.queue.directory).st_mode & 0o777, 0o700)
        for path in records:
            self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
        observed = []
        self.queue.drain(lambda event: observed.append(event) or True)
        self.assertEqual(len(observed), 12)

    def test_failed_final_event_retries_without_another_hook(self):
        self.enqueue("session-end")
        self.queue.drain(lambda event: False)
        self.assertIsNone(self.queue.next_event())
        with patch.object(queue_module.time, "time", return_value=10**12):
            restarted = Queue(self.queue.directory)
            observed = []
            restarted.drain(lambda event: observed.append(event) or True)
        self.assertEqual([item["event"] for item in observed], ["session-end"])
        self.assertEqual(list(self.queue.directory.glob("*.json")), [])

    def test_failed_progress_blocks_final_for_same_trace_only(self):
        self.enqueue("agent-done")
        self.enqueue("session-end")
        self.enqueue("session-end", session="session-b")
        observed = []

        def run(event):
            observed.append(event["event"])
            return event["event"] == "session-end"

        self.queue.drain(run)
        self.assertEqual(observed, ["agent-done", "session-end"])
        record = json.loads(next(self.queue.directory.glob("*.json")).read_text())
        self.assertIn("progress", record)
        self.assertIn("end", record)

    def test_runner_retains_exact_arguments_and_waits_for_cgroup(self):
        self.enqueue("session-end", value="$UNCHANGED")
        event = self.queue.next_event()[2]
        event["environment"] = {"TRACES_API_URL": "https://example.invalid/private"}
        with patch.object(queue_module.subprocess, "run") as run:
            run.return_value.returncode = 0
            self.assertTrue(queue_module.run_hook(event))
        command = run.call_args.args[0]
        self.assertIn("--property=ExitType=cgroup", command)
        self.assertIn("--wait", command)
        self.assertIn("--property=RuntimeMaxSec=900", command)
        self.assertIn("--slice=traces-uploads.slice", command)
        self.assertIn("--expand-environment=no", command)
        self.assertEqual(
            command[-5:], ["hook", "agent", "session-end", "--agent", "codex"]
        )
        self.assertEqual(run.call_args.kwargs["input"], event["payload"])
        self.assertIn("--setenv=TRACES_API_URL", command)
        self.assertNotIn("https://example.invalid/private", " ".join(command))
        self.assertEqual(
            run.call_args.kwargs["env"]["TRACES_API_URL"],
            "https://example.invalid/private",
        )

    def test_failed_wakeup_keeps_final_payload_for_timer(self):
        payload = '{"session_id":"final-session","value":"$UNCHANGED"}'
        with (
            patch.object(
                queue_module.sys,
                "argv",
                [
                    str(SCRIPT),
                    "--state-dir",
                    str(self.queue.directory),
                    "enqueue",
                    "session-end",
                    "--agent",
                    "codex",
                ],
            ),
            patch.object(queue_module.sys, "stdin", io.StringIO(payload)),
            patch.object(queue_module.shutil, "which", return_value="/bin/true"),
            patch.object(
                queue_module.subprocess,
                "run",
                side_effect=subprocess.TimeoutExpired("systemctl", 2),
            ),
        ):
            queue_module.main()
        observed = []
        Queue(self.queue.directory).drain(lambda event: observed.append(event) or True)
        self.assertEqual(len(observed), 1)
        self.assertEqual(observed[0]["payload"], payload)
        self.assertEqual(observed[0]["arguments"], ["--agent", "codex"])

    def test_final_retry_keeps_resolved_id_after_registration_is_removed(self):
        repo = Path(self.temporary.name) / "repo"
        subprocess.run(["git", "init", "--quiet", str(repo)], check=True)
        active = repo / ".git/traces-active.json"
        active.write_text(
            json.dumps(
                {
                    "sessions": [
                        {
                            "agentId": "codex",
                            "agentSessionId": "native-session",
                            "traceId": "resolved-trace-id",
                        }
                    ]
                }
            )
        )
        self.queue.enqueue(
            "session-end",
            ["--agent", "codex"],
            '{"session_id":"native-session"}',
            "/bin/true",
            str(repo),
        )

        def timeout_after_removal(event):
            saved = json.loads(next(self.queue.directory.glob("*.json")).read_text())
            self.assertEqual(saved["end"]["trace_id"], "resolved-trace-id")
            self.assertFalse(event["share_retry"])
            active.unlink()
            return False

        self.queue.drain(timeout_after_removal, queue_module.prepare_final)
        with patch.object(queue_module.time, "time", return_value=10**12):
            restarted = Queue(self.queue.directory)
            observed = []
            restarted.drain(
                lambda event: observed.append(event) or True, queue_module.prepare_final
            )
        self.assertTrue(observed[0]["share_retry"])
        with patch.object(queue_module.subprocess, "run") as run:
            run.return_value.returncode = 0
            queue_module.run_hook(observed[0])
        self.assertEqual(
            run.call_args.args[0][-6:],
            [
                "share",
                "--trace-id",
                "resolved-trace-id",
                "--source",
                "agent_hook",
                "--json",
            ],
        )
        self.assertEqual(run.call_args.kwargs["input"], "")

    def test_native_session_fields_coalesce_for_supported_hooks(self):
        for agent, field in (
            ("codex", "id"),
            ("cursor", "conversation_id"),
            ("antigravity", "conversationId"),
            ("openclaw", "sessionKey"),
        ):
            for event in ("prompt-submitted", "agent-done", "session-end"):
                self.queue.enqueue(
                    event,
                    ["--agent=" + agent],
                    json.dumps({field: "session"}),
                    "/bin/true",
                    "/tmp",
                )
        self.assertEqual(len(list(self.queue.directory.glob("*.json"))), 4)
        observed = []
        self.queue.drain(lambda event: observed.append(event) or True)
        self.assertEqual(len(observed), 8)

    def test_coalesced_final_preserves_prepared_trace_identity(self):
        self.enqueue("session-end", generation=1)
        path, slot, event = self.queue.next_event()
        event["trace_id"] = "resolved-trace-id"
        self.queue.write(path, {slot: event})
        self.enqueue("session-end", generation=2)
        self.queue.finish(path, slot, event, True)
        newer = self.queue.next_event()[2]
        self.assertEqual(newer["trace_id"], "resolved-trace-id")
        self.assertEqual(json.loads(newer["payload"])["generation"], 2)


if __name__ == "__main__":
    unittest.main()
