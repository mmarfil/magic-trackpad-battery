import runpy
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RENDER = runpy.run_path(str(ROOT / "magic-trackpad-battery-waybar"))["render"]


class WaybarRenderingTests(unittest.TestCase):
    def test_hides_disconnected_or_invalid_state(self):
        self.assertEqual(RENDER({"connected": False}), {"text": ""})
        self.assertEqual(
            RENDER(
                {
                    "connected": True,
                    "percentage": "20",
                    "charging": False,
                    "device_name": "Apple Magic Trackpad",
                    "updated_at": 1000,
                },
                now=1000,
            ),
            {"text": ""},
        )

    def test_renders_and_escapes_connected_state(self):
        output = RENDER(
            {
                "connected": True,
                "percentage": 20,
                "charging": True,
                "device_name": 'Quoted "Trackpad" <&>',
                "updated_at": 1000,
            },
            now=1000,
        )

        self.assertEqual(output["class"], "critical")
        self.assertEqual(output["text"], '<span alpha="50%">MTP</span> 20%')
        self.assertEqual(
            output["tooltip"],
            "Quoted &quot;Trackpad&quot; &lt;&amp;&gt;: 20% (charging)",
        )

    def test_hides_stale_connected_state(self):
        output = RENDER(
            {
                "connected": True,
                "percentage": 50,
                "charging": False,
                "device_name": "Apple Magic Trackpad",
                "updated_at": 1000,
            },
            now=1361,
        )
        self.assertEqual(output, {"text": ""})


if __name__ == "__main__":
    unittest.main()
