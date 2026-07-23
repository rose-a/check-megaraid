# check-megaraid

Python 3 MegaRAID monitor for Proxmox VE. Replaces noisy `smartd` emails on MegaRAID hot spares (SMART passthrough often fails on spun-down DHS/GHS) with real controller/array/disk checks.

## What it does

| Mode | When | Notification |
|------|------|----------------|
| `--check` (default) | every 15 minutes via systemd | only if unhealthy (severity `error`, title `MegaRAID HOST: ALERT`) |
| `--monthly` | 1st of month ~09:00 | always: `HEALTHY` (`info`) or `UNHEALTHY` (`error`) with full storcli dumps |

Commands used:

1. `storcli show` — overall `Hlth`, `DNOpt`, `VNOpt`
2. `storcli /c0 show` — VD list, PD list, enclosure

Healthy when:

- `Hlth=Opt`, `DNOpt=0`, `VNOpt=0` (`BBU=N/A` is OK on PRAID CP400i)
- every VD `Optl`
- every PD `Onln`, `DHS`, or `GHS` (spun-down spare is fine)
- enclosure `OK`

Unhealthy examples: PD `UBad` (even if VDs stay Optimal after spare takeover), rebuild/`Rbld`, degraded VD, non-`Opt` controller health.

## Delivery (PVE notifications)

Alerts are **not** sent with custom `sendmail`/MIME. The script calls Proxmox’s notification stack (`PVE::Notify::notify`, template type `simple`) so mail looks like other PVE/PBS notices.

Routing uses **Datacenter → Notifications** (matchers / sendmail or SMTP targets). Do **not** mail local `root` yourself—that path (`system-mail` / `proxmox-mail-forward`) flattens multipart and produces empty or one-line messages.

This uses the internal `libpve-notify-perl` API (same approach as [community scripts](https://forum.proxmox.com/threads/hook-custom-script-into-notifications-system.162766/)). It can break on PVE package upgrades; re-test after updates.

## Install on PVE host

```bash
cd check-megaraid
chmod +x check-megaraid install.sh
./install.sh
```

Requires `python3`, `perl`, `PVE::Notify` (Proxmox VE), and `storcli` on PATH.

### Disable smartd monitoring

If there are no non-RAID disks, in `/etc/smartd.conf`:

```text
DEVICESCAN -d ignore
```

Do **not** monitor `/dev/bus/0` / `megaraid_disk_*` with smartd.

### Verify

```bash
/usr/local/sbin/check-megaraid --check
/usr/local/sbin/check-megaraid --monthly --dry-run
/usr/local/sbin/check-megaraid --test
systemctl list-timers 'check-megaraid*'
```

Confirm the test notification arrives as a normal Proxmox-style email (readable plain + HTML).

### Offline fixture test (no controller / no notify)

```bash
./check-megaraid --check --dry-run \
  --show-file storcli-samples/show.txt \
  --c0-file storcli-samples/c0-healty.txt
# expect exit 0, no notify

./check-megaraid --check --dry-run \
  --show-file storcli-samples/show.txt \
  --c0-file storcli-samples/bad-disk-hotspare-took-over.txt
# expect exit 1 and dry-run ALERT with State=UBad
```

## Why not `storcli /c0 show alarm`?

That property is only the physical buzzer (`on`/`off`/`silence`/`ABSENT`). On CP400i it stays `ABSENT` and does not reflect disk or array health.

## Layout

```text
check-megaraid          # Python 3 script
install.sh              # install + enable timers
systemd/                # .service / .timer units
storcli-samples/        # captured outputs for parser tests
README.md
```
