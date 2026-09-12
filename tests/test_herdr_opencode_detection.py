import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HERDR = shutil.which("herdr")
MANIFEST = ROOT / "config/herdr/agent-detection/opencode.toml"
IDLE_FOOTER = """  ┃
  ┃
  ┃  Build · Example model
  ╹▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
   /workspace/org/repo                42K (4%) ctrl+p commands
"""


@unittest.skipUnless(HERDR, "Herdr is required for native detection regression tests")
class OpenCodeDetectionTests(unittest.TestCase):
    def detect(self, screen):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "config/herdr"
            manifests = config / "agent-detection"
            manifests.mkdir(parents=True)
            shutil.copyfile(MANIFEST, manifests / "opencode.toml")
            capture = root / "screen.txt"
            capture.write_text(screen)
            environment = dict(os.environ)
            environment.update(
                XDG_CONFIG_HOME=str(root / "config"),
                XDG_STATE_HOME=str(root / "state"),
                HERDR_CONFIG_PATH=str(config / "config.toml"),
            )
            result = subprocess.run(
                [
                    HERDR,
                    "agent",
                    "explain",
                    "--file",
                    str(capture),
                    "--agent",
                    "opencode",
                    "--json",
                ],
                env=environment,
                capture_output=True,
                text=True,
                check=True,
                timeout=15,
            )
            decoded = json.loads(result.stdout)
            self.assertIn(str(manifests), decoded["manifest_source"])
            return decoded["state"]

    def test_quoted_worker_interrupt_hint_does_not_keep_completed_turn_busy(self):
        for hint in (
            "esc to interrupt",
            "ctrl+c to interrupt",
            "press esc to interrupt",
        ):
            with self.subTest(hint=hint):
                screen = (
                    f"  ┃  • Working (6s • {hint})\n"
                    "  ┃  Click to expand\n\n"
                    "     Worker dispatched.\n\n"
                    "     ▣ Build · Example model · 3m 36s\n" + IDLE_FOOTER
                )
                self.assertEqual(self.detect(screen), "idle")

    def test_quoted_progress_bar_does_not_keep_completed_turn_busy(self):
        screen = "  ┃  ⬝⬝⬝⬝⬝⬝⬝⬝ esc interrupt\n" + IDLE_FOOTER
        self.assertEqual(self.detect(screen), "idle")

    def test_native_busy_and_retry_footers_remain_working(self):
        for footer in (
            "   ⬝⬝⬝⬝⬝⬝⬝⬝ esc interrupt  • OpenCode 1.18.25\n",
            "   ■■■■ Gateway Timeout [retrying in 25s] esc interrupt\n",
            "   esc to interrupt\n",
            "   ctrl+c to interrupt\n",
            "   OpenCode esc again to interrupt\n",
            "   ⬝⬝⬝⬝ esc interrupt\n   42K (4%) ctrl+p\n   commands\n",
        ):
            with self.subTest(footer=footer):
                self.assertEqual(self.detect(IDLE_FOOTER + footer), "working")

    def test_permission_prompt_remains_blocked_even_with_busy_footer(self):
        screen = (
            "  △ Permission required\n  Run shell command?\n"
            + IDLE_FOOTER
            + "   ⬝⬝⬝⬝ esc interrupt\n"
        )
        self.assertEqual(self.detect(screen), "blocked")

    def test_confirmation_prompt_remains_blocked(self):
        screen = "  esc dismiss  enter confirm  ↑↓ select\n" + IDLE_FOOTER
        self.assertEqual(self.detect(screen), "blocked")


if __name__ == "__main__":
    unittest.main()
