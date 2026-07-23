# check-megaraid

Storcli-based MegaRAID monitoring for Proxmox VE. Replaces noisy `smartd` emails on MegaRAID hot spares (SMART passthrough often fails on spun-down DHS/GHS) with real controller/array/disk checks.

## What it does

| Mode | When | Mail |
|------|------|------|
| `--check` (default) | every 15 minutes via systemd | only if unhealthy (`MegaRAID HOST: ALERT`) |
| `--monthly` | 1st of month ~09:00 | always, full dumps (`MegaRAID HOST: HEALTHY` or `UNHEALTHY`) |

Commands used:

1. `storcli show` — overall `Hlth`, `DNOpt`, `VNOpt`
2. `storcli /c0 show` — VD list, PD list, enclosure

Healthy when:

- `Hlth=Opt`, `DNOpt=0`, `VNOpt=0` (`BBU=N/A` is OK on PRAID CP400i)
- every VD `Optl`
- every PD `Onln`, `DHS`, or `GHS` (spun-down spare is fine)
- enclosure `OK`

Unhealthy examples: PD `UBad` (even if VDs stay Optimal after spare takeover), rebuild/`Rbld`, degraded VD, non-`Opt` controller health.

Mail goes to `root` by default (Proxmox forwards root@pam). Override with `CHECK_MEGARAID_MAIL_TO`.

Messages are sent via `sendmail` as `multipart/alternative` (plain text + HTML `<pre>`) so line breaks survive in Nextcloud Mail and desktop MUAs.

## Install on PVE host

```bash
# copy this directory to the host, then:
cd check-megaraid
chmod +x check-megaraid install.sh
./install.sh
```

Requires `storcli` on PATH (on pve1: `/usr/bin/storcli` → `/opt/MegaRAID/storcli/storcli64`).

### Disable smartd monitoring

If there are no non-RAID disks on this host, put this in `/etc/smartd.conf` so it monitors nothing:

```text
DEVICESCAN -d ignore
```

Do **not** monitor `/dev/bus/0` / `megaraid_disk_*` with smartd.

### Verify

```bash
# silent exit 0 when healthy
/usr/local/sbin/check-megaraid --check

# preview monthly mail
/usr/local/sbin/check-megaraid --monthly --dry-run

# real test mail through Proxmox mail setup
/usr/local/sbin/check-megaraid --test-mail

systemctl list-timers 'check-megaraid*'
```

### Offline fixture test (no controller needed)

From this repo:

```bash
./check-megaraid --check --dry-run \
  --show-file storcli-samples/show.txt \
  --c0-file storcli-samples/c0-healty.txt
# expect exit 0, no mail

./check-megaraid --check --dry-run \
  --show-file storcli-samples/show.txt \
  --c0-file storcli-samples/bad-disk-hotspare-took-over.txt
# expect exit 1 and ALERT mail dump mentioning PD ... State=UBad

./check-megaraid --monthly --dry-run \
  --show-file storcli-samples/show.txt \
  --c0-file storcli-samples/c0-healty.txt
# expect HEALTHY subject and full command output in body
```

## Why not `storcli /c0 show alarm`?

That property is only the physical buzzer (`on`/`off`/`silence`/`ABSENT`). On CP400i it stays `ABSENT` and does not reflect disk or array health.

## Layout

```text
check-megaraid          # main script
install.sh              # install + enable timers
systemd/                # .service / .timer units
storcli-samples/        # captured outputs for parser tests
README.md
```
