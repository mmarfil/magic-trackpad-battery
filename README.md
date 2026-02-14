# magic-trackpad-battery

Battery monitor for Apple Magic Trackpad on Linux (Bluetooth).

A lightweight daemon that reads battery percentage from Apple Magic Trackpad over Bluetooth, where the kernel reports 0%.

## The Problem

Linux's `hid_magicmouse` kernel driver implements battery reporting only over USB. When connected via Bluetooth, the kernel power_supply subsystem always shows 0% — even though the device does report battery status over HID.

## The Solution

This daemon reads the battery directly from the hidraw device using the `HIDIOCGINPUT` ioctl to fetch HID Input Report `0x90`. The 3-byte report contains:

| Byte | Contents |
|------|----------|
| 0 | Report ID (`0x90`) |
| 1 | Status flags (bit 1 = charging) |
| 2 | Battery capacity (0–100%) |

The daemon polls every 5 minutes and writes the result as JSON for easy integration with status bars like Waybar.

## Quick Install

```bash
git clone https://github.com/mmarfil/magic-trackpad-battery.git
cd magic-trackpad-battery
make install
```

Then install the udev rule (requires sudo) and enable the service:

```bash
# Grant your user access to the hidraw device
sudo install -Dm644 99-magic-trackpad.rules /etc/udev/rules.d/99-magic-trackpad.rules
sudo udevadm control --reload-rules

# Start the battery monitor
systemctl --user daemon-reload
systemctl --user enable --now magic-trackpad-battery
```

## Uninstall

```bash
make uninstall
sudo rm -f /etc/udev/rules.d/99-magic-trackpad.rules
sudo udevadm control --reload-rules
```

## Waybar Integration

Add a custom module to your Waybar config (`~/.config/waybar/config.jsonc`):

```jsonc
"custom/trackpad-battery": {
    "exec": "~/.local/bin/magic-trackpad-battery-waybar",
    "return-type": "json",
    "interval": 60,
    "format": "{}",
    "tooltip": true,
    "markup": true
}
```

Add it to your modules list (e.g., `"modules-right"`). The module hides itself automatically when the trackpad is disconnected.

The Waybar helper uses Pango markup to dim the device label, so `"markup": true` is required.

**Device labels:** The helper auto-detects the device type from its Bluetooth name and shows a short label:

| Device | Label |
|--------|-------|
| Magic Trackpad | MTP |
| Magic Mouse | MM |
| Magic Keyboard | MK |
| Other | HID |

## How It Works

1. **Device discovery:** Scans `/sys/class/hidraw/` for devices whose `uevent` contains `DRIVER=magicmouse`
2. **hidraw access:** Opens `/dev/hidrawN` and issues `HIDIOCGINPUT` ioctl (read Input Report by ID)
3. **Battery parsing:** Report `0x90` returns `[id, status, capacity]` — capacity is percentage, status bit 1 is charging
4. **JSON output:** Writes `{"percentage": N, "charging": bool, "connected": bool, "device_name": str}` atomically via rename
5. **Low battery alerts:** Sends desktop notifications via `notify-send` at 20%, 15%, 10%, 5%
6. **Reconnection:** When the device disconnects, the daemon re-scans every 30 seconds

The udev rule sets `GROUP="input"` so any user in the `input` group can read the hidraw device — no root required for the daemon itself.

## File Locations

| File | Installed to |
|------|-------------|
| `magic-trackpad-battery` | `~/.local/bin/` |
| `magic-trackpad-battery-waybar` | `~/.local/bin/` |
| `magic-trackpad-battery.service` | `~/.config/systemd/user/` |
| `99-magic-trackpad.rules` | `/etc/udev/rules.d/` (sudo) |
| Battery JSON | `$XDG_RUNTIME_DIR/magic-trackpad-battery.json` |

## Compatibility

| Device | Status |
|--------|--------|
| Magic Trackpad 2 (A1535) | Confirmed working |
| Magic Trackpad (USB-C, A1535-like) | Should work (same HID protocol) |
| Magic Mouse | Likely works (same `hid_magicmouse` driver) |
| Magic Keyboard | Likely works (same HID battery report) |

## Troubleshooting

**"Permission denied" opening hidraw:**
- Ensure the udev rule is installed and rules are reloaded
- Reconnect the trackpad (udev rules apply on device connect)
- Check: `ls -la /dev/hidraw*` — the magicmouse device should show `crw-rw----` with your user having access

**Device not found:**
- Verify Bluetooth connection: `bluetoothctl info` should show the trackpad as connected
- Check the driver: `grep -r magicmouse /sys/class/hidraw/*/device/uevent`
- The `hid_magicmouse` module must be loaded: `lsmod | grep hid_magicmouse`

**JSON file not updating:**
- Check service status: `systemctl --user status magic-trackpad-battery`
- Check logs: `journalctl --user -u magic-trackpad-battery -f`

**Waybar module not showing:**
- The module is hidden when the trackpad is disconnected (empty `text` field)
- Verify the JSON: `cat ${XDG_RUNTIME_DIR:-/tmp}/magic-trackpad-battery.json`
- Run the helper manually: `~/.local/bin/magic-trackpad-battery-waybar`

## Dependencies

- Python 3 (standard library only — no pip packages)
- `notify-send` (from `libnotify`) for low battery alerts
- systemd (for the user service)
- A Bluetooth stack (BlueZ) with the trackpad paired and connected

## License

MIT
