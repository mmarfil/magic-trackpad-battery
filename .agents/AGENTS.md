# magic-trackpad-battery

Battery monitor for Apple Magic Trackpad on Linux (Bluetooth).

## Project Overview

A lightweight daemon that reads battery percentage from Apple Magic Trackpad
via hidraw/HID Input Report 0x90, since the kernel's hid_magicmouse driver
only reports battery over USB (always 0% on Bluetooth).

## Tech Stack

- **Language:** Python 3 (stdlib only), Bash
- **Platform:** Linux (Arch/systemd)
- **Integration:** Waybar (custom module), notify-send (low battery alerts)
- **Install:** AUR package (`magic-trackpad-battery-git`) or Makefile for development

## Key Files

| File | Purpose |
|------|---------|
| `magic-trackpad-battery` | Main daemon (Python) — polls hidraw every 5 min |
| `magic-trackpad-battery-waybar` | Waybar helper (Bash) — reads JSON, outputs Waybar format |
| `magic-trackpad-connect` | Auto-connect script (Bash) — reconnects paired devices via bluetoothctl |
| `magic-trackpad-battery.service` | systemd user service for battery daemon |
| `magic-trackpad-autoconnect.service` | systemd oneshot service for auto-connect |
| `magic-trackpad-autoconnect.timer` | systemd timer — runs auto-connect every 30s |
| `99-magic-trackpad.rules` | udev rule for hidraw access (GROUP="input") |
| `Makefile` | install / uninstall / test targets |
| `aur/PKGBUILD` | Arch Linux AUR package definition |

## Development Notes

- No external dependencies — Python stdlib + coreutils only
- The daemon writes JSON atomically (rename) to `$XDG_RUNTIME_DIR/`
- Low battery notifications at 20%, 15%, 10%, 5%
- Device reconnection: re-scans /sys/class/hidraw/ every 30s when disconnected
