#!/usr/bin/env bash
# Guided Proton Drive setup: rclone remote (interactive Proton login — the
# one step that can't be automated) + the user mount service the repo ships.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

command -v rclone >/dev/null 2>&1 || { err "rclone missing — run 'make packages' first."; exit 1; }

if ! rclone listremotes 2>/dev/null | grep -qx "protondrive:"; then
    log "No 'protondrive' remote configured yet."
    log "rclone will now walk you through it — create a remote named exactly"
    log "'protondrive' with storage type 'protondrive', using your Proton login."
    rclone config
fi

if ! rclone listremotes 2>/dev/null | grep -qx "protondrive:"; then
    err "Remote 'protondrive' still missing — re-run 'make protondrive'."
    exit 1
fi
ok "rclone remote 'protondrive' present."

log "Enabling the mount service (mounts at ~/ProtonDrive)"
run systemctl --user daemon-reload
run systemctl --user enable --now protondrive.service
if [ "$DRY_RUN" != "1" ]; then
    sleep 2
    if systemctl --user is-active --quiet protondrive.service; then
        ok "Proton Drive mounted at ~/ProtonDrive."
    else
        err "Service failed to start — check: journalctl --user -u protondrive.service"
        exit 1
    fi
fi
