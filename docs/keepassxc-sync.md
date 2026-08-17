# KeePassXC, synced across machines

Your password database lives at `~/KeePassXC/KeepassXCdb.kdbx` and is kept in
step with Proton Drive both ways, every fifteen minutes.

    make keepassxc      set it up on a machine (one time)

## Why not just use the Proton Drive mount

`~/ProtonDrive` is an rclone mount, which makes files on it network files. For a
password database that is three problems: no connection means no passwords, every
save is a network round trip, and a VFS layer that fumbles an atomic write can
corrupt the file. `rclone bisync` keeps a **real local file** and reconciles it
with the remote afterwards, so KeePassXC only ever writes to local disk and the
database opens on a train.

## The layout

```
~/KeePassXC/                          the database, and nothing else
    KeepassXCdb.kdbx
    RCLONE_TEST                       marker; --check-access refuses to sync without it
protondrive:KeePassXC/                the other side

~/.local/share/keepassxc-backups/     anything overwritten or deleted, locally
protondrive:KeePassXC-replaced/       the same, remotely
~/.local/state/keepassxc-sync.log     what the last runs did
```

The database sits in its **own directory** because bisync works on directories.
Syncing `$HOME` with a filter would work too, right up to the first filter
mistake — and then rclone is operating on everything you own.

## What it refuses to do

These are the choices that matter, and they are all deliberately paranoid.
A sync tool given a password vault can lose passwords in three ways: overwrite,
delete, or pick the wrong side of a conflict. Each is blocked:

| | |
|---|---|
| `--max-delete 0` | never propagates a deletion, of anything, ever |
| `--conflict-resolve none` | when both machines changed the file, keeps **both** |
| `--check-access` | refuses to sync unless `RCLONE_TEST` is on both sides |
| `--backup-dir1/2` | anything overwritten is kept, not discarded |
| `--compare size,modtime,checksum` | Proton's modtimes are not always trustworthy; the checksum settles it |
| `*.lock` filtered | an open database here must not look "locked" over there |

## When the sync stops

**It will tell you.** A blocked sync is the exact failure this exists to
prevent, so it is loud: an error in the journal *and* a desktop notification.

The usual cause is a deletion. Because `--max-delete 0` aborts rather than
skips, one deleted file blocks **every** later run until you decide:

```bash
bash ~/lukasawesome/scripts/keepassxc-sync.sh status         # what is going on
bash ~/lukasawesome/scripts/keepassxc-sync.sh allow-delete   # yes, I meant it
```

`allow-delete` shows what would go, asks, and keeps a copy in the backup
directories regardless.

## When both machines changed it

Nothing is overwritten. You get both files, the second named `…conflict1`, and
`status` points them out. Open each in KeePassXC, copy across whatever the other
one has, and delete the extra. This is rare — it needs the database edited on
two machines inside one fifteen-minute window without a sync between.

## Adding another computer

1. `make keepassxc` there. It creates `~/KeePassXC/` and pulls the database down.
2. Do **not** run `init` on the second machine if it already has a database you
   care about — `init` seeds from the local copy and would push it over the
   remote. Move that copy aside first, sync, then merge by hand.

## The database and git

It must never reach a repository, and four things keep it out:

- it lives in `~/KeePassXC`, which is inside no repository
- `*.kdbx` and `*.kdbx.lock` are in `lukasawesome/.gitignore`
- nothing this setup writes goes into a repository
- `make check-system` fails loudly if a `.kdbx` ever appears in one

## Secret Service (why this setup does not use it)

KeePassXC can act as the system Secret Service (`org.freedesktop.secrets`), so
every application asks *it* for passwords. This machine deliberately uses
**gnome-keyring** for that instead, because eduroam needs its password at login —
before you have unlocked anything. gnome-keyring is unlocked by PAM with your
login password; KeePassXC is locked until you type your master password, so
switching would mean re-entering the wifi password after every reboot.

Both are installed; only one owns the D-Bus name. If you ever want to switch,
the article this setup came from covers it:
<https://www.lshnk.me/2025/12/02/arch-linux-bulletproof-keepassxc-integration-with-rclone-and-secret-service-api/>

## Checking on it

```bash
bash ~/lukasawesome/scripts/keepassxc-sync.sh status
systemctl --user list-timers keepassxc-sync
journalctl --user -u keepassxc-sync -n 20
```
