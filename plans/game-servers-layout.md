---
node: game-servers-layout
title: GameServers folder and blue server slice on the storage bar
status: done
created: 2026-11-19
tags: [gaming, storage, docker, minecraft]
---

# GameServers folder and blue server slice on the storage bar

## Goal

Give dedicated game servers a home at `/mnt/games/GameServers/`, move the live
Minecraft world there, make that the hub's default for new servers, and show
game-server storage as a blue segment on the Gaming → Storage partition bar.

## Scope

In:
- Move `/mnt/games/MinecraftServer` → `/mnt/games/GameServers/Minecraft` and
  recreate the container with the new bind mount. No world changes.
- Change the model fallback and the create-form default to the new path.
- Add a numeric `dataBytes` field to the size query so the bar can be proportional.
- Split the partition bar into blue (servers) + used + free, with a 6px floor
  for blue and a legend printing the real size and percentage.
- Tests, version bump, live verification, commit.

Out:
- Moving Docker's root `/var/lib/docker` off the system drive.
- Changing the Minecraft version, world, memory, or port.
- Backups, whitelists, mod management.

## Decisions

- Elena chose server data only, not all of Docker. Every other container stays
  where it is.
- True proportion makes a 243M world ~0.02% of a 1TB partition — sub-pixel.
  Blue gets a 6px minimum so it is visible, and the legend carries the honest
  number. The percentage is of *used* space, not total.

## Steps

1. `model/Gaming.mjs`: emit `dataBytes` from `du -sb`, parse it, add
   `gameServerTotalBytes`, export the wrapper.
2. `Panel.qml`: `gameServerDataBytes` state, set on size parse, reset on empty,
   expose in `status()`; new default data dir.
3. `ui/tabs/GamesTab.qml`: stacked partition bar and legend.
4. `model/Docker.mjs`: new default data dir.
5. Tests in `test_gaming.py`, `test_docker.py`, `test_qml_structure.py`; mutate,
   run full suite, qmllint, plugin validate.
6. Move the data, recreate the container from the model-generated command,
   restart the shell, verify live, bump version, commit and push.

## Risks

- Recreating the container is a few seconds of downtime. Verify `level.dat`
  exists in the destination before `docker rm` of the old container.
- `du -sb` reports apparent size while `du -sh` reports allocated size; the two
  display figures can differ slightly. The bar uses bytes, the card uses `-sh`.
- A second server created without editing the data-dir field would reuse the
  first path. The field is visible and editable; document it in the plan.
- QML width binding must not form a cycle: track width comes from the parent,
  never from its children.

## Done when

`/mnt/games/GameServers/Minecraft` holds the live world, the container is
healthy on 25565 with that mount, new servers default under `GameServers`, and
the Storage bar shows a visible blue slice with an accurate legend. All checks
pass and the change is pushed.
