import os
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONNECT = ROOT / "magic-trackpad-connect"


class ConnectScriptTests(unittest.TestCase):
    def run_with_bluetoothctl(self, script):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            fake = directory / "bluetoothctl"
            fake.write_text("#!/bin/sh\n" + textwrap.dedent(script))
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            call_log = directory / "calls"
            result = subprocess.run(
                [str(CONNECT)],
                env={
                    **os.environ,
                    "PATH": f"{directory}{os.pathsep}{os.environ['PATH']}",
                    "CALL_LOG": str(call_log),
                    "CONNECT_TIMEOUT": "1",
                    "MAGIC_TRACKPAD_MAC": "",
                },
                text=True,
                capture_output=True,
            )
            calls = call_log.read_text().splitlines() if call_log.exists() else []
            return result, calls

    def test_discovery_failure_is_operational_error(self):
        result, _calls = self.run_with_bluetoothctl("exit 1\n")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unable to list", result.stdout)

    def test_no_paired_trackpad_is_successful_noop(self):
        result, _calls = self.run_with_bluetoothctl("exit 0\n")
        self.assertEqual(result.returncode, 0)
        self.assertIn("no paired", result.stdout)

    def test_offline_trackpad_gets_one_connect_attempt(self):
        result, calls = self.run_with_bluetoothctl(
            """
            printf '%s\\n' "$*" >> "$CALL_LOG"
            case "$*" in
              *"devices Paired"*)
                echo "Device AA:BB:CC:DD:EE:FF Apple Magic Trackpad"
                exit 0
                ;;
              *" info "*)
                echo "Connected: no"
                exit 0
                ;;
              *" connect "*)
                exit 1
                ;;
            esac
            exit 1
            """
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(sum(" connect " in f" {call} " for call in calls), 1)


if __name__ == "__main__":
    unittest.main()
