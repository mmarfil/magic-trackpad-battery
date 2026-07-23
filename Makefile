BINDIR          = $(HOME)/.local/bin
XDG_CONFIG_HOME ?= $(HOME)/.config
SYSTEMDDIR      = $(XDG_CONFIG_HOME)/systemd/user
UDEVDIR         = /etc/udev/rules.d

.PHONY: install uninstall test probe help aur-check aur-publish

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
	@echo "     sudo rm -f $(UDEVDIR)/99-magic-trackpad.rules"
	@echo "     sudo install -Dm644 72-magic-trackpad.rules $(UDEVDIR)/72-magic-trackpad.rules"
	@echo "     sudo udevadm control --reload-rules"
	@echo "     Reconnect the Trackpad so the rule is applied."
	@echo ""
	@echo "  2. Enable and start the services:"
	@echo "     systemctl --user daemon-reload"
	@echo "     systemctl --user enable magic-trackpad-battery"
	@echo "     systemctl --user restart magic-trackpad-battery"
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
	systemctl --user daemon-reload
	@echo ""
	@echo "Removed. To also remove the udev rule:"
	@echo "  sudo rm -f $(UDEVDIR)/72-magic-trackpad.rules"
	@echo "  sudo udevadm control --reload-rules"

AUR_REMOTE = ssh://aur@aur.archlinux.org/magic-trackpad-battery-git.git

aur-check: ## Verify PKGBUILD version metadata
	@set -eu; \
	actual=$$(awk -F= '$$1 == "pkgver" { print $$2; exit }' aur/PKGBUILD); \
	current="r$$(git rev-list --count HEAD).$$(git rev-parse --short HEAD)"; \
	previous="r$$(git rev-list --count HEAD^).$$(git rev-parse --short HEAD^)"; \
	if [ "$$actual" != "$$current" ] && [ "$$actual" != "$$previous" ]; then \
		echo "PKGBUILD pkgver $$actual is stale; expected $$current before its commit or $$previous after it." >&2; \
		exit 1; \
	fi; \
	echo "PKGBUILD version: $$actual"

aur-publish: aur-check ## Publish PKGBUILD to AUR
	@if [ -n "$$(git status --porcelain)" ]; then echo "Working tree must be clean before publishing." >&2; exit 1; fi
	@if upstream=$$(git rev-parse '@{upstream}' 2>/dev/null); then \
		test "$$(git rev-parse HEAD)" = "$$upstream" || { echo "Push the main repository before publishing." >&2; exit 1; }; \
	else \
		echo "The current branch has no upstream." >&2; exit 1; \
	fi
	@set -eu; \
	tmpdir=$$(mktemp -d); \
	trap 'find "$$tmpdir" -depth -delete 2>/dev/null || true' EXIT; \
	git clone $(AUR_REMOTE) "$$tmpdir"; \
	cp aur/PKGBUILD "$$tmpdir/PKGBUILD"; \
	(cd "$$tmpdir" && makepkg --printsrcinfo > .SRCINFO); \
	git -C "$$tmpdir" add PKGBUILD .SRCINFO; \
	set +e; git -C "$$tmpdir" diff --cached --quiet; status=$$?; set -e; \
	case $$status in \
		0) echo "AUR already up to date." ;; \
		1) version=$$(awk -F= '$$1 == "pkgver" { print $$2; exit }' aur/PKGBUILD); \
		   git -C "$$tmpdir" commit -m "Update to $$version"; \
		   git -C "$$tmpdir" push ;; \
		*) exit $$status ;; \
	esac

test: ## Run automated tests
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v

probe: ## Find a connected Bluetooth Magic Trackpad
	@python3 -c 'import runpy; find = runpy.run_path("magic-trackpad-battery")["find_hidraw"]; device, name = find(); print(f"Found: {device} ({name})" if device else "No Bluetooth Magic Trackpad found."); raise SystemExit(0 if device else 1)'
