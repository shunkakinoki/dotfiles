"""Optional restart targets skip absent units and surface real failures."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class OptionalServiceTests(unittest.TestCase):
    def test_restart_results(self):
        for service in ("docker-postgres", "ollama"):
            cases = (("not-found", "0"), ("loaded", "0"), ("loaded", "3"))
            for state, failure in cases:
                with self.subTest(service=service, state=state, failure=failure):
                    with tempfile.TemporaryDirectory() as directory:
                        root = Path(directory)
                        mock = root / "systemctl"
                        mock.write_text(
                            '#!/bin/sh\nif [ "$2" = show ]; then\n'
                            '  echo "$UNIT_STATE"\nelse\n'
                            '  echo "$*" >> "$RESTART_LOG"\n'
                            '  exit "$RESTART_RESULT"\nfi\n'
                        )
                        mock.chmod(0o755)
                        log = root / "restart.log"
                        result = subprocess.run(
                            [
                                "make",
                                f"systemctl-{service}",
                                "HOST=kamino1",
                                "DETECTED_HOST=kamino1",
                                "TAILSCALE_DNS_NAME=",
                            ],
                            cwd=ROOT,
                            env={
                                **os.environ,
                                "PATH": f"{root}:{os.environ['PATH']}",
                                "UNIT_STATE": state,
                                "RESTART_RESULT": failure,
                                "RESTART_LOG": str(log),
                            },
                            capture_output=True,
                            text=True,
                            timeout=30,
                        )
                        if state == "not-found":
                            self.assertFalse(log.exists())
                            self.assertEqual(result.returncode, 0, result.stderr)
                            self.assertIn("Skipping", result.stdout)
                            self.assertNotIn("restarted", result.stdout)
                        else:
                            self.assertEqual(
                                log.read_text().strip(),
                                f"--user restart {service}.service",
                            )
                            self.assertEqual(result.returncode == 0, failure == "0")
                            self.assertEqual(
                                "restarted" in result.stdout, failure == "0"
                            )
