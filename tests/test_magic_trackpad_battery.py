import contextlib
import io
import json
import runpy
import tempfile
import unittest
from pathlib import Path
from unittest.mock import mock_open, patch


ROOT = Path(__file__).resolve().parents[1]


def load_daemon():
    return runpy.run_path(str(ROOT / "magic-trackpad-battery"))


class DeviceDiscoveryTests(unittest.TestCase):
    def discover(self, uevent):
        find_hidraw = load_daemon()["find_hidraw"]
        with patch.object(find_hidraw.__globals__["os"], "listdir", return_value=["hidraw9"]):
            with patch("builtins.open", mock_open(read_data=uevent)):
                return find_hidraw()

    def test_accepts_bluetooth_magic_trackpad(self):
        result = self.discover(
            "DRIVER=magicmouse\n"
            "HID_ID=0005:0000004C:00000265\n"
            "HID_NAME=Apple Inc. Magic Trackpad\n"
        )
        self.assertEqual(result, ("/dev/hidraw9", "Apple Inc. Magic Trackpad"))

    def test_rejects_usb_magic_trackpad(self):
        result = self.discover(
            "DRIVER=magicmouse\n"
            "HID_ID=0003:000005AC:00000265\n"
            "HID_NAME=Apple Inc. Magic Trackpad\n"
        )
        self.assertEqual(result, (None, None))

    def test_rejects_other_magicmouse_devices(self):
        result = self.discover(
            "DRIVER=magicmouse\n"
            "HID_ID=0005:0000004C:00000269\n"
            "HID_NAME=Apple Magic Mouse\n"
        )
        self.assertEqual(result, (None, None))


class BatteryReportTests(unittest.TestCase):
    def test_parses_capacity_and_charging_flag(self):
        read_battery = load_daemon()["read_battery"]

        def fill_report(_fd, _request, buffer):
            buffer[:] = bytes([0x90, 0x02, 67])

        with patch.object(read_battery.__globals__["fcntl"], "ioctl", side_effect=fill_report):
            self.assertEqual(read_battery(3), (67, True))

    def test_returns_none_when_ioctl_fails(self):
        read_battery = load_daemon()["read_battery"]
        with patch.object(read_battery.__globals__["fcntl"], "ioctl", side_effect=OSError):
            self.assertIsNone(read_battery(3))


class StateWritingTests(unittest.TestCase):
    def test_replaces_state_atomically(self):
        write_json = load_daemon()["write_json"]
        with tempfile.TemporaryDirectory() as runtime_dir:
            path = Path(runtime_dir, "magic-trackpad-battery.json")
            with patch.dict(write_json.__globals__["os"].environ, {"XDG_RUNTIME_DIR": runtime_dir}):
                with patch.object(write_json.__globals__["time"], "time", return_value=123):
                    write_json({"connected": False})

            self.assertEqual(
                json.loads(path.read_text()),
                {"connected": False, "updated_at": 123},
            )
            self.assertFalse(Path(f"{path}.tmp").exists())


class NotificationTests(unittest.TestCase):
    def test_steady_low_reading_notifies_once(self):
        check_low_battery = load_daemon()["check_low_battery"]
        notifications = []
        check_low_battery.__globals__["notify_low_battery"] = notifications.append
        notified = set()

        for _poll in range(4):
            notified = check_low_battery(10, False, notified)

        self.assertEqual(notifications, [10])
        self.assertEqual(notified, {20, 15, 10})

    def test_notifier_errors_do_not_escape(self):
        notify = load_daemon()["notify_low_battery"]
        with patch.object(notify.__globals__["subprocess"], "Popen", side_effect=FileNotFoundError):
            with contextlib.redirect_stderr(io.StringIO()):
                notify(20)


if __name__ == "__main__":
    unittest.main()
