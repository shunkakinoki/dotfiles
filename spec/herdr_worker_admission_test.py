import copy
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "admission", ROOT / "config/shared/hooks/herdr-worker-admission.py"
)
admission = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(admission)


class WorkerAdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.path = self.home / ".herdr/worktrees/demo/topic"
        self.path.mkdir(parents=True)
        self.source = self.home / "repo"
        self.source.mkdir()
        self.args = ["worker", "--kind", "codex", "--pane", "w1:p1"]
        self.data = {
            ("pane", "get", "w1:p1"): {
                "pane": {
                    "pane_id": "w1:p1",
                    "workspace_id": "w1",
                    "cwd": str(self.path),
                }
            },
            ("workspace", "get", "w1"): {
                "workspace": {
                    "workspace_id": "w1",
                    "worktree": {
                        "checkout_path": str(self.path),
                        "is_linked_worktree": True,
                        "repo_name": "demo",
                        "repo_root": str(self.source),
                    },
                }
            },
            ("worktree", "list", "--cwd", str(self.source)): {
                "worktrees": [
                    {
                        "path": str(self.path),
                        "is_linked_worktree": True,
                        "open_workspace_id": "w1",
                    }
                ]
            },
            ("agent", "list"): {"agents": []},
        }
        self.calls = []

    def read(self, args):
        self.calls.append(args)
        return copy.deepcopy(self.data[tuple(args)])

    def check(self, args=None):
        return admission.require_worker_worktree(
            args or self.args, read=self.read, home=self.home, host="host.example"
        )

    def test_valid_linked_worker_uses_only_four_read_probes(self):
        self.assertEqual(self.check(), str(self.path))
        self.assertEqual(
            [args[:2] for args in self.calls],
            [
                ["pane", "get"],
                ["workspace", "get"],
                ["worktree", "list"],
                ["agent", "list"],
            ],
        )

    def test_root_workspace_is_refused_before_ownership_or_launch(self):
        self.data[("workspace", "get", "w1")]["workspace"]["worktree"][
            "is_linked_worktree"
        ] = False
        with self.assertRaisesRegex(admission.AdmissionError, "linked Herdr"):
            self.check()
        self.assertEqual(len(self.calls), 2)

    def test_missing_and_malformed_metadata_are_refused(self):
        workspace = self.data[("workspace", "get", "w1")]["workspace"]
        for worktree in (None, {}, {"is_linked_worktree": "true"}):
            with self.subTest(worktree=worktree):
                workspace["worktree"] = worktree
                with self.assertRaises(admission.AdmissionError):
                    self.check()

    def test_cwd_mismatch_is_refused(self):
        self.data[("pane", "get", "w1:p1")]["pane"]["cwd"] = str(self.source)
        with self.assertRaisesRegex(admission.AdmissionError, "cwd"):
            self.check()

    def test_linked_checkout_outside_herdr_root_is_refused(self):
        self.data[("workspace", "get", "w1")]["workspace"]["worktree"][
            "checkout_path"
        ] = str(self.source)
        with self.assertRaises(admission.AdmissionError):
            self.check()

    def test_contradictory_worktree_association_is_refused(self):
        self.data[("worktree", "list", "--cwd", str(self.source))]["worktrees"][0][
            "open_workspace_id"
        ] = "w2"
        with self.assertRaisesRegex(admission.AdmissionError, "disagree"):
            self.check()

    def test_moved_pane_alias_uses_returned_workspace(self):
        pane = self.data[("pane", "get", "w1:p1")]["pane"]
        pane.update(workspace_id="w2", pane_id="w2:p3")
        workspace = self.data.pop(("workspace", "get", "w1"))
        workspace["workspace"]["workspace_id"] = "w2"
        self.data[("workspace", "get", "w2")] = workspace
        self.data[("worktree", "list", "--cwd", str(self.source))]["worktrees"][0][
            "open_workspace_id"
        ] = "w2"
        self.assertEqual(self.check(), str(self.path))

    def test_settled_other_owner_blocks_renamed_duplicate(self):
        self.data[("agent", "list")]["agents"] = [
            {
                "name": "worker",
                "pane_id": "w1:p2",
                "cwd": str(self.path),
                "agent_status": "done",
            }
        ]
        with self.assertRaisesRegex(admission.AdmissionError, "another owner"):
            self.check(["worker_b", "--kind", "codex", "--pane", "w1:p1"])

    def test_same_name_in_other_checkout_is_refused(self):
        self.data[("agent", "list")]["agents"] = [
            {
                "name": "worker",
                "pane_id": "w2:p1",
                "cwd": str(self.source),
            }
        ]
        with self.assertRaises(admission.AdmissionError):
            self.check()

    def test_target_pane_owned_under_stale_cwd_is_refused(self):
        self.data[("agent", "list")]["agents"] = [
            {
                "name": "other_worker",
                "pane_id": "w1:p1",
                "cwd": str(self.source),
            }
        ]
        with self.assertRaises(admission.AdmissionError):
            self.check()

    def test_existing_same_owner_is_preserved(self):
        self.data[("agent", "list")]["agents"] = [
            {
                "name": "worker",
                "pane_id": "w1:p1",
                "cwd": str(self.path),
            }
        ]
        self.assertEqual(self.check(), str(self.path))

    def test_orchestrators_and_help_need_no_worker_probes(self):
        for name in (
            "host_orchestrator",
            "host_co_orchestrator",
            "host_co_orchestrator_fallback",
        ):
            self.assertIsNone(self.check([name, "--kind", "codex", "--pane", "w1:p1"]))
        self.assertIsNone(self.check(["--help"]))
        self.assertEqual(self.calls, [])

    def test_dynamic_or_implicit_worker_pane_is_refused(self):
        for args in (["worker"], ["worker", "--pane", "$PANE"]):
            with self.assertRaises(admission.AdmissionError):
                self.check(args)

    def test_agent_help_after_separator_does_not_bypass_admission(self):
        self.data[("workspace", "get", "w1")]["workspace"]["worktree"] = None
        with self.assertRaises(admission.AdmissionError):
            self.check(self.args + ["--", "--help"])

    def test_options_before_name_remain_supported(self):
        self.assertEqual(
            self.check(["--kind=codex", "--pane=w1:p1", "worker"]), str(self.path)
        )

    def test_unreadable_probe_is_refused(self):
        def unavailable(args):
            raise admission.AdmissionError("unavailable")

        with self.assertRaises(admission.AdmissionError):
            admission.require_worker_worktree(self.args, read=unavailable)

    def test_shell_commands_and_quoted_examples_are_distinguished(self):
        launch = "herdr agent start worker --kind codex --pane w1:p1"
        for command in (
            launch,
            "true && " + launch,
            "true # comment\n" + launch,
            "bash -lc " + repr(launch),
        ):
            self.assertEqual(list(admission.starts(command)), [self.args])
        for command in (
            "echo " + repr(launch),
            "echo ';' " + launch,
            "herdr agent read worker",
            "herdr agent prompt worker 'held'",
        ):
            self.assertEqual(list(admission.starts(command)), [])

    def test_open_code_bash_envelope_reaches_existing_shared_hook(self):
        self.data[("workspace", "get", "w1")]["workspace"]["worktree"] = None
        fixture = self.home / "responses.json"
        fixture.write_text(
            json.dumps(
                {json.dumps(list(key)): value for key, value in self.data.items()}
            )
        )
        binary_dir = self.home / ".cargo/bin"
        binary_dir.mkdir(parents=True)
        binary = binary_dir / "herdr"
        binary.write_text(
            "#!/usr/bin/env python3\nimport json,os,sys\n"
            "data=json.load(open(os.environ['ADMISSION_FIXTURE']))\n"
            "print(json.dumps({'result':data[json.dumps(sys.argv[1:])]}))\n"
        )
        binary.chmod(0o755)
        env = dict(os.environ, HOME=str(self.home), ADMISSION_FIXTURE=str(fixture))
        env["PATH"] = str(binary_dir) + os.pathsep + os.environ["PATH"]
        payload = {
            "tool_name": "bash",
            "tool_input": {
                "command": "herdr agent start worker --kind codex --pane w1:p1",
            },
        }
        result = subprocess.run(
            [shutil.which("bash"), str(ROOT / "config/shared/hooks/security.sh")],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            env=env,
        )
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("linked Herdr worktree", result.stderr)
        config = json.loads((ROOT / "config/opencode/hooks.json").read_text())
        hook = config["hooks"]["PreToolUse"][0]
        self.assertEqual(hook["matcher"], "bash")
        self.assertGreaterEqual(hook["hooks"][0]["timeout"], 5000)
        self.assertIn("config/shared/hooks/security.sh", hook["hooks"][0]["command"])


if __name__ == "__main__":
    unittest.main()
