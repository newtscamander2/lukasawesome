# System snapshots with Timeshift (btrfs)

Automatic btrfs snapshots of the system and `/home`, so a bad update or a
deleted file can be undone. Set up by `scripts/timeshift-snapshots.sh`.

This assumes the disk layout `archinstall` produces with **btrfs + LUKS + the
default subvolume layout** (see the top of the README): one encrypted btrfs
filesystem with `@`, `@home`, `@pkg` and `@log` subvolumes.

## Why btrfs mode, not rsync mode

Timeshift defaults to rsync mode, which copies files and takes minutes. On a
laptop that is a real problem: close the lid mid-run and the snapshot is cut
off, leaving a partial directory behind.

btrfs mode instead uses copy-on-write snapshots of the `@` and `@home`
subvolumes. They are **atomic and take under a second**, so an interrupted
snapshot is not a failure mode that exists.

| | rsync mode | btrfs mode |
|--------------------|--------------------------|--------------------------|
| Snapshot time | minutes | < 1 second |
| Interrupted mid-run| partial dir, wasted space| cannot happen (atomic) |
| Space per snapshot | full copy first time | ~0, grows as data diverges |
| Requires | any filesystem | btrfs with `@` / `@home` |

## What is and is not snapshotted

Timeshift's btrfs mode snapshots **only the `@` and `@home` subvolumes**, and
btrfs snapshots are *not* recursive — anything on a nested subvolume is
excluded automatically.

| Path | Subvolume | Snapshotted | Notes |
|-------------------------|-----------|-------------|-------|
| `/` | `@` | yes | `/etc`, `/usr`, `/opt`, `/srv`, `/root`, most of `/var` |
| `/home` | `@home` | yes | all of `~` and every subdirectory |
| `/boot` | — (vfat) | **no** | separate ESP partition — see below |
| `/var/log` | `@log` | no | deliberate: logs survive a restore |
| `/var/cache/pacman/pkg` | `@pkg` | no | deliberate: package cache is re-downloadable |
| `/tmp`, `/run` | — | no | tmpfs, not on disk |

### The `/boot` gap

The ESP is mounted at `/boot` and is **vfat**, so btrfs cannot snapshot it.
Kernel images and initramfs live there; kernel *modules* live in
`/usr/lib/modules`, inside `@`. The two can desync:

> Snapshot taken → kernel update lands → restore the snapshot. `/boot` still
> holds the **new** kernel, but `@` has been rolled back to only the **old**
> kernel's modules. The new kernel boots and finds no matching modules
> directory: no network drivers, possibly no boot at all.

After any restore that spans a kernel update, chroot in and reinstall the
kernel to regenerate `/boot` and the initramfs:

```bash
pacman -S linux        # regenerates /boot + runs mkinitcpio
```

Restores that don't cross a kernel update are unaffected. This is inherent to
having a vfat ESP at `/boot`; no configuration works around it.

## Setup

```bash
sudo scripts/timeshift-snapshots.sh
```

Safe to re-run — it is the way to apply changes after editing the tunables at
the top of the file. It backs up `/etc/timeshift/timeshift.json` (timestamped)
before touching it, and aborts if `/` is not btrfs or the root subvolume is not
named `@`.

Device UUIDs are detected at runtime rather than hardcoded, so the script keeps
working after a reinstall.

### Tunables

Edit at the top of the script, then re-run it.

| Variable | Default | Meaning |
|---------------------------|---------|---------|
| `INCLUDE_HOME` | `true` | snapshot `@home` as well as `@` |
| `INCLUDE_HOME_ON_RESTORE` | `false` | roll `/home` back when restoring |
| `SCHED_BOOT` / `COUNT_BOOT` | `true` / 5 | snapshot 10 min after boot |
| `SCHED_DAILY` / `COUNT_DAILY` | `true` / 7 | one per day, keep a week |
| `SCHED_WEEKLY` / `COUNT_WEEKLY` | `true` / 4 | one per week, keep a month |
| `SCHED_MONTHLY` / `COUNT_MONTHLY` | `false` / 2 | off |
| `SCHED_HOURLY` / `COUNT_HOURLY` | `false` / 6 | off |
| `TAKE_FIRST_SNAPSHOT` | `true` | snapshot once at the end to verify |

**Backup and restore are separate settings.** Including `/home` in snapshots
does *not* mean a system restore reverts your documents — that stays an
explicit choice via `INCLUDE_HOME_ON_RESTORE`. Note this diverges from
upstream Timeshift's design intent, which is to protect system files only.

## Scheduling: cron, plus a systemd timer for catch-up

Timeshift schedules via cron and **rewrites `/etc/cron.d/timeshift-{hourly,boot}`
on every run** — not just when you save settings in the GUI. Deleting those
files does not stick: the next snapshot recreates them. So cron is left to own
the in-session schedule, and a systemd timer is added alongside it for the one
thing cron cannot do.

| Source | Trigger | Runs |
|--------|---------|------|
| `/etc/cron.d/timeshift-hourly` | `0 * * * *` | `timeshift --check` |
| `/etc/cron.d/timeshift-boot` | `@reboot` + 10 min | `timeshift --create --tags B` |
| `timeshift-check.timer` | `OnCalendar=hourly`, `Persistent=true` | `timeshift --check` |

Cron's weakness on a laptop is that it has **no catch-up**: a job due while the
machine is asleep is skipped outright, and it only fires if the machine happens
to be awake at that exact minute. `Persistent=true` closes that gap — if the
window passed while suspended or powered off, the timer fires as soon as the
machine is awake again.

The overlap is safe: `timeshift --check` is idempotent (it creates a snapshot
only if one is actually due, and applies the retention counts), and Timeshift
holds a single-instance lock so two runs can never collide.

`timeshift-check.service` wraps its command in `systemd-inhibit --mode=block`,
so closing the lid during a snapshot *defers* the suspend until it finishes.
Cron-triggered runs are **not** wrapped — but btrfs snapshots complete in well
under a second (`BTRFS Snapshot saved successfully (0s)` in the journal), so
the exposure is negligible.

> Boot snapshots come from cron's `@reboot` entry. Do not add a systemd timer
> for them as well — that produces two boot snapshots racing for the lock on
> every boot.

## Recovering individual files

Snapshots are read-only directories. For "I deleted or mangled a file", browse
them directly — no restore needed, nothing can be damaged:

```bash
sudo mount -o subvol=/ /dev/mapper/root /mnt
ls /mnt/timeshift-btrfs/snapshots/                 # pick a date
cp -a /mnt/timeshift-btrfs/snapshots/<date>/@home/lukas/path/to/file ~/
sudo umount /mnt
```

## Restoring the whole system

```bash
sudo timeshift --restore                 # interactive, pick a snapshot
sudo timeshift --restore --snapshot '2026-08-15_14-00-01'
```

Re-read [the `/boot` gap](#the-boot-gap) first if a kernel update happened
after the snapshot you're restoring.

Timeshift can only restore from a running system or its own live-boot path. If
an update leaves the machine **unbootable**, you need an Arch live USB to get
in and run the restore from there. (Snapper + `grub-btrfs` puts snapshots in
the boot menu and avoids this; it's the more idiomatic Arch stack, but a
larger setup.)

## Everyday commands

```bash
timeshift --list                              # list snapshots + sizes
sudo timeshift --create --comments "before X" # manual snapshot
sudo systemctl start timeshift-check.service  # force a due-check now
systemctl list-timers 'timeshift-*'           # when the next run is due
journalctl -u timeshift-check.service -n 50   # errors from scheduled runs
sudo timeshift-gtk                            # GUI (see caveat)
```

## Troubleshooting

- **No snapshots appearing.** Check the timer is enabled and has a `NEXT`
  time: `systemctl list-timers 'timeshift-*'`. Then look at
  `journalctl -u timeshift-check.service`.
- **`timeshift-gtk` overwrites the config.** Saving settings in the GUI rewrites
  `/etc/timeshift/timeshift.json`, including the `include_btrfs_home_for_*`
  keys. Re-run `sudo scripts/timeshift-snapshots.sh` afterwards to put the
  tunables back. The cron files it also rewrites are expected and fine.
- **"Another instance of this application is running (PID=…)".** Harmless: a
  cron `--check` fired at the same moment and holds the single-instance lock.
  The other process is creating the snapshot; check with `timeshift --list`.
- **Snapshots eating disk.** `~` is included, so moving large files around
  (VM images, video, big downloads) keeps deleted data alive in old snapshots.
  `timeshift --list` shows sizes; lower `COUNT_DAILY` / `COUNT_WEEKLY` and
  re-run the script, or delete individual snapshots with
  `sudo timeshift --delete --snapshot '<name>'`.
- **Config looks wrong.** Every run backs up to
  `/etc/timeshift/timeshift.json.bak.<timestamp>`; restore one and re-run.

## This is not a backup

Snapshots live on the same btrfs filesystem as the data they protect. They
undo mistakes; they do not survive a failed SSD, a lost laptop, or a corrupted
LUKS header.

System files are replaceable from packages. `~` is not — keep a real off-disk
copy of it as well (Proton Drive via `make protondrive`, or an external drive).
