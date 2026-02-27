PREFIX     ?= $(HOME)/.local
BINDIR      = $(PREFIX)/bin
SYSTEMDDIR  = $(HOME)/.config/systemd/user
UDEVDIR     = /etc/udev/rules.d

.PHONY: install uninstall test help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

install: ## Install daemon, Waybar helper, connect script, and systemd units
	install -Dm755 magic-trackpad-battery $(BINDIR)/magic-trackpad-battery
	install -Dm755 magic-trackpad-battery-waybar $(BINDIR)/magic-trackpad-battery-waybar
	install -Dm755 magic-trackpad-connect $(BINDIR)/magic-trackpad-connect
	install -Dm644 magic-trackpad-battery.service $(SYSTEMDDIR)/magic-trackpad-battery.service
	install -Dm644 magic-trackpad-autoconnect.service $(SYSTEMDDIR)/magic-trackpad-autoconnect.service
	install -Dm644 magic-trackpad-autoconnect.timer $(SYSTEMDDIR)/magic-trackpad-autoconnect.timer
	@echo ""
	@echo "Installed to $(BINDIR) and $(SYSTEMDDIR)."
	@echo ""
	@echo "Next steps:"
	@echo "  1. Install udev rule (requires sudo):"
	@echo "     sudo install -Dm644 99-magic-trackpad.rules $(UDEVDIR)/99-magic-trackpad.rules"
	@echo "     sudo udevadm control --reload-rules"
	@echo ""
	@echo "  2. Enable and start the services:"
	@echo "     systemctl --user daemon-reload"
	@echo "     systemctl --user enable --now magic-trackpad-battery"
	@echo "     systemctl --user enable --now magic-trackpad-autoconnect.timer"

uninstall: ## Remove all scripts and systemd units
	systemctl --user disable --now magic-trackpad-battery 2>/dev/null || true
	systemctl --user disable --now magic-trackpad-autoconnect.timer 2>/dev/null || true
	rm -f $(BINDIR)/magic-trackpad-battery
	rm -f $(BINDIR)/magic-trackpad-battery-waybar
	rm -f $(BINDIR)/magic-trackpad-connect
	rm -f $(SYSTEMDDIR)/magic-trackpad-battery.service
	rm -f $(SYSTEMDDIR)/magic-trackpad-autoconnect.service
	rm -f $(SYSTEMDDIR)/magic-trackpad-autoconnect.timer
	@echo ""
	@echo "Removed. To also remove the udev rule:"
	@echo "  sudo rm -f $(UDEVDIR)/99-magic-trackpad.rules"
	@echo "  sudo udevadm control --reload-rules"

test: ## Quick test: find device and read battery once
	@echo "Looking for Magic Trackpad hidraw device..."
	@for dev in /sys/class/hidraw/hidraw*; do \
	  if grep -q 'DRIVER=magicmouse' "$$dev/device/uevent" 2>/dev/null; then \
	    echo "  Found: /dev/$$(basename $$dev)"; \
	    exit 0; \
	  fi; \
	done; \
	echo "  No device found. Is the trackpad connected via Bluetooth?"
