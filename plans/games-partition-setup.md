---
node: games-partition-setup
title: Hub-managed Games partition creation and fstab setup
status: draft
created: 2026-11-20
tags: [gaming, storage, fstab, planning]
---

# Hub-managed Games partition creation and fstab setup

## Goal

Let the hub create the `/mnt/games` partition for Elena (or another user) from
scratch: partition free space on the same drive or use a second drive, format
it, write the fstab entry, and mount it — internal or external — without the
user doing the disk work by hand.

## Scope

In (future):
- Inventory disks and free space (`lsblk -J`, `findmnt`, `blkid`, `df`) and show
  what is available: free space on the system drive vs a whole second drive.
- A wizard step to choose the target: new partition on the same drive, or a
  second drive (internal or USB/external).
- Generate the partition, filesystem, fstab and mount commands, preview them,
  then mount at the hub's `gameMount` (`/mnt/games`).
- Reuse `gameMount` as the single source of truth so the server wizard's world
  default follows whatever `/mnt/games` resolves to.
- Idempotent: detect an existing `/mnt/games` mount and skip creation.

Out:
- Any destructive action without an explicit, per-disk confirmation.
- Moving Docker's root `/var/lib/docker`.
- Changing existing server data or the current `/mnt/games` contents.
- RAID, LVM, encryption, or network mounts.

## Steps

1. Model helpers (pure): disk inventory command + parser, and a planner that
   turns a target choice into a concrete command list.
2. Preflight UI: list candidate disks with size/type/mount state; disable
   targets that hold the OS or an existing filesystem.
3. Wizard step: target selection, mount point confirmation, full command
   preview, and a typed confirmation before anything runs.
4. fstab writer: stable identifier (UUID, or `/dev/disk/by-id` for external),
   `nofail,x-systemd.device-timeout=...` for external drives so boot does not
   hang when a USB disk is unplugged. Back up fstab first, offer rollback.
5. Mount, verify with `findmnt`, restart the shell, re-run the server wizard's
   mount detection. Tests, qmllint, plugin validate, live dry run.

## Risks

- Partitioning/formatting is destructive. Confirm the exact disk twice; refuse
  any disk that is mounted, holds the OS, or contains an existing filesystem
  unless explicitly overridden.
- `/dev/sdX` names shift between boots. Use UUID or by-id in fstab, never the
  raw device name.
- A bad fstab line can break boot. Back up `/etc/fstab`, validate with
  `findmnt --verify` (or `mount -a` in a check pass), and keep a rollback path.
- Needs privilege (`pkexec`/interactive sudo). Follow the repo rule: report the
  exact command rather than attempting silent installs.
- External drives may be absent at boot: `nofail` is mandatory there.

## Done when

From a fresh disk or free space, the hub can create and mount `/mnt/games`,
write a correct fstab entry that survives reboot, leave existing data untouched
unless explicitly confirmed, and the server wizard picks up the new mount —
with all checks passing and the change pushed.
