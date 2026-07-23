#!/usr/bin/env bash
# Install check-megaraid and enable systemd timers on Proxmox/Debian.
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

if ! perl -MPVE::Notify -e '1' 2>/dev/null; then
  echo "WARNING: PVE::Notify not loadable (need Proxmox VE / libpve-notify-perl)" >&2
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"

install -d /usr/local/sbin
install -m 0755 "$ROOT/check-megaraid" /usr/local/sbin/check-megaraid

install -d /usr/local/share/doc/check-megaraid
install -m 0644 "$ROOT/README.md" /usr/local/share/doc/check-megaraid/README.md

install -m 0644 "$ROOT/systemd/check-megaraid.service" /etc/systemd/system/
install -m 0644 "$ROOT/systemd/check-megaraid.timer" /etc/systemd/system/
install -m 0644 "$ROOT/systemd/check-megaraid-monthly.service" /etc/systemd/system/
install -m 0644 "$ROOT/systemd/check-megaraid-monthly.timer" /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now check-megaraid.timer
systemctl enable --now check-megaraid-monthly.timer

if ! command -v storcli >/dev/null 2>&1; then
  echo "WARNING: storcli not found on PATH (expected /usr/bin/storcli)" >&2
fi

echo "Installed. Timers:"
systemctl list-timers 'check-megaraid*' --no-pager || true
echo
echo "Notifications go through Datacenter → Notifications (PVE::Notify)."
echo "Next steps:"
echo "  1. systemctl disable --now smartd   # or smartmontools.service"
echo "  2. /usr/local/sbin/check-megaraid --check"
echo "  3. /usr/local/sbin/check-megaraid --monthly --dry-run"
echo "  4. /usr/local/sbin/check-megaraid --test"
