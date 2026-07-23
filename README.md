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

## Install (AUR)

```bash
yay -S magic-trackpad-battery-git
# Reconnect the Trackpad once so the new udev rule is applied.
systemctl --user enable --now magic-trackpad-battery
systemctl --user enable --now magic-trackpad-autoconnect.timer
```

## Uninstall (AUR)

```bash
systemctl --user disable --now magic-trackpad-battery
systemctl --user disable --now magic-trackpad-autoconnect.timer
yay -R magic-trackpad-battery-git
sudo udevadm control --reload-rules
systemctl --user daemon-reload
```

## Manual Install

For development or non-Arch systems:

```bash
git clone https://github.com/mmarfil/magic-trackpad-battery.git
cd magic-trackpad-battery
make install
```

Then install the udev rule (requires sudo) and enable the service:

```bash
sudo rm -f /etc/udev/rules.d/99-magic-trackpad.rules  # remove the superseded rule, if present
sudo install -Dm644 72-magic-trackpad.rules /etc/udev/rules.d/72-magic-trackpad.rules
sudo udevadm control --reload-rules
# Reconnect the Trackpad once so the new rule is applied.
systemctl --user daemon-reload
systemctl --user enable magic-trackpad-battery
systemctl --user restart magic-trackpad-battery
systemctl --user enable --now magic-trackpad-autoconnect.timer
```

To remove a manual install:

```bash
make uninstall
sudo rm -f /etc/udev/rules.d/72-magic-trackpad.rules
sudo udevadm control --reload-rules
```

## Waybar Integration

Add a custom module to your Waybar config (`~/.config/waybar/config.jsonc`):

```jsonc
"custom/trackpad-battery": {
    "exec": "magic-trackpad-battery-waybar",
    "return-type": "json",
    "interval": 60,
    "format": "{}",
    "tooltip": true,
    "markup": true
}
```

Add it to your modules list (e.g., `"modules-right"`). The module hides itself automatically when the trackpad is disconnected.

The helper displays the fixed label `MTP` and uses Pango markup to dim it, so `"markup": true` is required.

## Auto-Connect

The package includes an auto-connect script that periodically attempts to reconnect paired Magic Trackpad devices via Bluetooth. It runs as a systemd timer (every 30 seconds) and uses `bluetoothctl` to discover and connect paired devices.

The script auto-discovers any paired device with "Magic Trackpad" in its name — no MAC address configuration needed. You can also set `MAGIC_TRACKPAD_MAC` to target a specific device.

## How It Works

1. **Device discovery:** Scans `/sys/class/hidraw/` for a Bluetooth (`HID_ID=0005`) Magic Trackpad using the `magicmouse` driver
2. **hidraw access:** Opens `/dev/hidrawN` and issues `HIDIOCGINPUT` ioctl (read Input Report by ID)
3. **Battery parsing:** Report `0x90` returns `[id, status, capacity]` — capacity is percentage, status bit 1 is charging
4. **JSON output:** Writes connected state as `{"percentage": N, "charging": bool, "connected": true, "device_name": str, "updated_at": epoch}` atomically via rename. Disconnected state omits `device_name`.
5. **Low battery alerts:** Sends desktop notifications via `notify-send` at 20%, 15%, 10%, 5%
6. **Reconnection:** When the device disconnects, the daemon re-scans every 30 seconds

The udev rule grants hidraw access to the active local session through systemd-logind's `uaccess` ACL. No persistent input-group membership is required. Reconnect the Trackpad after installing or changing the rule.

## File Locations

| File | AUR package | Manual install |
|------|-------------|----------------|
| `magic-trackpad-battery` | `/usr/bin/` | `~/.local/bin/` |
| `magic-trackpad-battery-waybar` | `/usr/bin/` | `~/.local/bin/` |
| `magic-trackpad-connect` | `/usr/bin/` | `~/.local/bin/` |
| `magic-trackpad-battery.service` | `/usr/lib/systemd/user/` | `~/.config/systemd/user/` |
| `magic-trackpad-autoconnect.service` | `/usr/lib/systemd/user/` | `~/.config/systemd/user/` |
| `magic-trackpad-autoconnect.timer` | `/usr/lib/systemd/user/` | `~/.config/systemd/user/` |
| `72-magic-trackpad.rules` | `/usr/lib/udev/rules.d/` | `/etc/udev/rules.d/` (sudo) |
| Battery JSON | `$XDG_RUNTIME_DIR/magic-trackpad-battery.json` | same |

## Compatibility

| Device | Status |
|--------|--------|
| Magic Trackpad 2 (A1535) | Confirmed working |
| Magic Trackpad (USB-C) | Expected to work over Bluetooth; hardware confirmation pending |

## Troubleshooting

**"Permission denied" opening hidraw:**
- Ensure the udev rule is installed and rules are reloaded
- Reconnect the trackpad (udev rules apply on device connect)
- Check: `getfacl /dev/hidrawN` — the active user should have read/write access

**Device not found:**
- Find the address: `bluetoothctl devices Paired | grep -i 'Magic Trackpad'`
- Verify the connection: `bluetoothctl info <MAC>` should show `Connected: yes`
- Check the HID metadata: `grep -rE '^(DRIVER=magicmouse|HID_ID=0005:|HID_NAME=.*Magic Trackpad)' /sys/class/hidraw/*/device/uevent`
- The `hid_magicmouse` module must be loaded: `lsmod | grep hid_magicmouse`

**JSON file not updating:**
- Check service status: `systemctl --user status magic-trackpad-battery`
- Check logs: `journalctl --user -u magic-trackpad-battery -f`

**Waybar module not showing:**
- The module is hidden when the trackpad is disconnected (empty `text` field)
- Verify the JSON: `cat "$XDG_RUNTIME_DIR/magic-trackpad-battery.json"`
- Run the helper manually: `magic-trackpad-battery-waybar`

## Development Checks

```bash
make test   # deterministic, hardware-independent tests
make probe  # detect a connected Bluetooth Magic Trackpad
```

## Dependencies

- Python 3 (standard library only — no pip packages)
- `notify-send` (from `libnotify`) for low battery alerts
- `bluetoothctl` (from `bluez-utils`) for auto-connect
- systemd (for the user service and timer)
- A Bluetooth stack (BlueZ) with the trackpad paired and connected

## License

MIT
