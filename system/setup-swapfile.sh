#!/bin/bash
# Create a disk swapfile on btrfs as a second-tier shock absorber behind zram.
#
# Idempotent: safe to re-run, every step is skipped if already done.
# Override the size with:  SWAP_SIZE=8g ./setup-swapfile.sh
#
# Why not just `fallocate + mkswap`: btrfs refuses to swapon a file that is
# copy-on-write, compressed, or living on a snapshotted subvolume, because swap
# requires stable physical block mappings that those features deliberately
# break. So:
#   1. the swapfile gets its own top-level subvolume @swap. The root subvol @ IS
#      snapshotted (into /.snapshots), so the file cannot live under it.
#   2. `btrfs filesystem mkswapfile` sets NOCOW, disables compression, and
#      preallocates in one shot (needs btrfs-progs >= 6.1).
#   3. the @swap mount deliberately has no compress= option.
#
# zram keeps priority 100 and fills first; this file is priority 10 and only
# takes over once zram is full, giving earlyoom time to act before a hard stall.
#
# NOTE: this does not set up hibernation. Hibernating to a btrfs swapfile also
# needs `resume=UUID=... resume_offset=$(btrfs inspect-internal map-swapfile -r
# /swap/swapfile)` on the kernel cmdline.

set -euo pipefail

SWAP_SIZE="${SWAP_SIZE:-16g}"
SWAP_SUBVOL="@swap"
SWAP_MOUNT="/swap"
SWAP_FILE="$SWAP_MOUNT/swapfile"

if [[ $EUID -ne 0 ]]; then
    echo "==> Re-running with sudo..."
    exec sudo --preserve-env=SWAP_SIZE "$0" "$@"
fi

# ---- Preflight -------------------------------------------------------------

if [[ "$(findmnt -no FSTYPE /)" != "btrfs" ]]; then
    echo "ERROR: / is not btrfs. This script is btrfs-specific." >&2
    exit 1
fi

if ! btrfs filesystem mkswapfile --help >/dev/null 2>&1; then
    echo "ERROR: btrfs-progs is too old for 'mkswapfile' (need >= 6.1)." >&2
    exit 1
fi

ROOT_DEV="$(findmnt -no SOURCE --nofsroot /)"
FS_UUID="$(blkid -s UUID -o value "$ROOT_DEV")"

# Refuse to fill the disk. Compare requested size against available bytes.
SWAP_BYTES="$(numfmt --from=iec "${SWAP_SIZE^^}")"
AVAIL_BYTES="$(($(btrfs filesystem usage -b / | awk '/Free \(estimated\)/{print $3; exit}')))"
if (( SWAP_BYTES + 5368709120 > AVAIL_BYTES )); then
    echo "ERROR: need $SWAP_SIZE + 5 GiB headroom, only $(numfmt --to=iec "$AVAIL_BYTES") free." >&2
    exit 1
fi

echo "==> Device $ROOT_DEV (UUID=$FS_UUID)"
echo "==> Swap size $SWAP_SIZE, $(numfmt --to=iec "$AVAIL_BYTES") free on /"

# ---- 1. Top-level @swap subvolume -----------------------------------------
# Top-level subvolumes are only visible from subvolid=5, so mount that briefly.

TMP_ROOT="$(mktemp -d /tmp/btrfs-root.XXXXXX)"
cleanup() {
    umount -q "$TMP_ROOT" 2>/dev/null || true
    rmdir "$TMP_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

mount -o subvolid=5 "$ROOT_DEV" "$TMP_ROOT"

if [[ -d "$TMP_ROOT/$SWAP_SUBVOL" ]]; then
    echo "==> Subvolume $SWAP_SUBVOL already exists, skipping create"
else
    echo "==> Creating subvolume $SWAP_SUBVOL"
    btrfs subvolume create "$TMP_ROOT/$SWAP_SUBVOL"
fi

cleanup
trap - EXIT

# ---- 2. fstab entries ------------------------------------------------------
# systemd's fstab generator orders the .swap unit after the mount automatically
# via RequiresMountsFor, so the ordering here is not load-bearing.

add_fstab_line() {
    local match="$1" line="$2"
    if grep -qF "$match" /etc/fstab; then
        echo "==> fstab already references '$match', skipping"
    else
        echo "==> Adding to fstab: $match"
        printf '\n%s\n' "$line" >> /etc/fstab
    fi
}

if [[ ! -f /etc/fstab.bak-swapfile ]]; then
    cp /etc/fstab /etc/fstab.bak-swapfile
    echo "==> Backed up /etc/fstab to /etc/fstab.bak-swapfile"
fi

add_fstab_line "subvol=/$SWAP_SUBVOL" \
"# Swapfile subvolume - deliberately NOT compressed, and not snapshotted
UUID=$FS_UUID	$SWAP_MOUNT	btrfs	rw,noatime,subvol=/$SWAP_SUBVOL	0 0"

add_fstab_line "$SWAP_FILE" \
"# Disk swap, priority below zram (100) so zram is consumed first
$SWAP_FILE	none	swap	defaults,pri=10	0 0"

# ---- 3. Mount --------------------------------------------------------------

mkdir -p "$SWAP_MOUNT"
systemctl daemon-reload
if findmnt -no TARGET "$SWAP_MOUNT" >/dev/null 2>&1; then
    echo "==> $SWAP_MOUNT already mounted"
else
    echo "==> Mounting $SWAP_MOUNT"
    mount "$SWAP_MOUNT"
fi

# ---- 4. Create the swapfile ------------------------------------------------

if [[ -f "$SWAP_FILE" ]]; then
    echo "==> $SWAP_FILE already exists, skipping creation"
else
    echo "==> Creating $SWAP_FILE ($SWAP_SIZE)"
    btrfs filesystem mkswapfile --size "$SWAP_SIZE" --uuid clear "$SWAP_FILE"
    chmod 600 "$SWAP_FILE"
fi

# ---- 5. Activate -----------------------------------------------------------

if swapon --show=NAME --noheadings | grep -qF "$SWAP_FILE"; then
    echo "==> Already active"
else
    echo "==> Activating $SWAP_FILE"
    swapon "$SWAP_FILE" --priority 10
fi

# ---- 6. Verify -------------------------------------------------------------

echo
echo "==> Verifying swapfile attributes"
# C = NOCOW. Must be present, or btrfs would have refused the swapon above.
if lsattr "$SWAP_FILE" 2>/dev/null | awk '{print $1}' | grep -q C; then
    echo "    NOCOW (C) attribute: OK"
else
    echo "    WARNING: NOCOW attribute missing on $SWAP_FILE" >&2
fi

# Do NOT check the mount for compress=. btrfs compression is a filesystem-wide
# mount option, not per-subvolume: because / is already mounted compress=zstd:3,
# every later subvolume mount of the same device inherits it and the `compress`
# absence in our fstab line is silently ignored. That is harmless -- compression
# requires COW, so a NOCOW file is never compressed regardless of mount options,
# and btrfs's own swapon validation rejects any compressed or COW file. The
# successful swapon plus the C attribute above is the real proof.
echo "    Mount reports: $(findmnt -no OPTIONS "$SWAP_MOUNT")"
echo "    (compress= is inherited from / and does not apply to NOCOW files)"

# Prove the file has the stable single-extent mapping swap requires.
if btrfs inspect-internal map-swapfile -r "$SWAP_FILE" >/dev/null 2>&1; then
    echo "    Swapfile extent mapping: OK"
fi

echo
echo "==> Swap tiers now (zram should be priority 100, swapfile 10):"
swapon --show

# Reboot safety: the .swap unit is produced by systemd-fstab-generator into
# /run/systemd/generator/, which `systemd-analyze verify` cannot resolve by name.
# Query the live unit state instead -- if it is loaded and active, the fstab
# entries parsed correctly and will come back on their own after a reboot.
echo
echo "==> Reboot-safety check: generated swap unit state"
SWAP_UNIT="$(systemd-escape --path --suffix=swap "$SWAP_FILE")"
printf '    %s: %s / %s\n' "$SWAP_UNIT" \
    "$(systemctl is-enabled "$SWAP_UNIT" 2>&1 || true)" \
    "$(systemctl is-active "$SWAP_UNIT" 2>&1 || true)"
systemctl --no-pager --type=swap --all list-units | grep -E "swapfile|zram" || true
