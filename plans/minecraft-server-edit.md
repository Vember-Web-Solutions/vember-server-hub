---
node: minecraft-server-edit
title: Edit an existing Minecraft server
status: active
created: 2026-11-20
tags: [minecraft, docker, hub]
---

# Edit an existing Minecraft server

## Goal

Let an operator rename a Minecraft server, change its published port, and refresh its mods from a chosen Prism instance without losing its world or data dir.

## Scope

In:
- Edit button on Docker Minecraft server rows.
- Confirmation dialog with name, port, and Prism instance picker.
- Inspect the existing container to preserve type, version, memory, difficulty, image and data dir.
- Copy the selected instance's `mods` into the server data dir, plus `kubejs`, `config` and `defaultconfigs` when present.
- Recreate the container with the edited name/port, preserving `/data`.
- Wait for a real Minecraft status ping before reporting success.

Out:
- CurseForge download/API.
- Editing host-installed Steam servers.
- Deleting Prism instances or modpack files.
- Renaming the data dir; the existing bind stays attached to the recreated container.

## Steps

1. Add pure model helpers: inspect/parse a Minecraft container, refresh mods from a Prism instance, recreate a container, and compute free edit ports excluding the current container.
2. Add backend dialog state and process chain: inspect → edit → optional mod refresh → recreate → status ping → refresh list/notify.
3. Add the Edit dialog QML and wire it to the existing server row.
4. Add model/QML structure tests and run qmllint, plugin validate, diff check and pytest.

## Risks

- Docker cannot rename or republish in place; Save must recreate. The dialog must say this plainly.
- A bad new name/port could collide with another container; the backend must refuse before removing the old container.
- Replacing `data/mods` is destructive but scoped to the chosen server and covered by the confirmation.
- Modpack config may be required for custom worlds; copying support dirs alongside mods keeps that fix available.

## Done when

A confirmed edit preserves the server data dir, applies the new name/port, copies the chosen Prism instance's mods, and reports success only after a real status ping on the new port. All repo checks pass.
