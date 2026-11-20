---
node: minecraft-client-template
title: Stable Prism template and a user-chosen Minecraft client
status: active
created: 2026-11-20
tags: [minecraft, prism, launcher, hub]
---

# Stable Prism template and a user-chosen Minecraft client

## Goal

Separate the Prism clone template from user-facing join instances, and let Elena
choose Prism or the official launcher per server and per launch.

## Scope

In:
- A hub-owned `minecraft-server` Prism instance used only as a clone source.
- `minecraft-join` (auto-join `vemberos:25565`) and `minecraft-vanilla` (main
  menu) cloned from that template, with both keybindings repointed at them.
- `vemberos-server` / `vemberos-vanilla` stay in Trash; nothing is restored.
- Per-server client default from wizard step 1 and the Edit dialog, stored in
  the instance sidecar and read back for display.
- A client picker on the Servers join bar: `Server default`, `Prism`, `Official`.
- An `Official launcher` button in the Gaming client bar, alongside the Prism
  vanilla button and the per-server Join buttons (Elena's addition).
- Official path writes `~/.minecraft/servers.dat` and opens `minecraft-launcher`.
- Tests, qmllint, plugin validation, diff check, live verification, bump, push.

Out:
- Restoring the trashed instances or changing their Trash metadata.
- CurseForge downloads or mod-level fixes.
- Auto-join for the official launcher; it has no such flag, so the player clicks
  the listed server once.
- Touching the installed modpack instances or their files.

## Decisions

- Elena chose **replace with template**, not restore. The trashed pair is only
  read once as a seed, then the template is self-contained.
- Elena chose **both** for client choice: a per-server default set in the
  wizard/Edit form, overridable for one launch from the join bar.
- Template id `minecraft-server`; keybinding ids `minecraft-join` and
  `minecraft-vanilla`. `minecraftInstanceId` reserves all three.
- The official launcher already has `bigheads` and `vemberos` entries; the new
  write path adds the launched server and preserves existing entries.

## Steps

1. Model helpers: `minecraftPrismSetupCommand`, client-aware
   `minecraftServerInstanceCommand`, `minecraftClientDefaultsCommand`,
   `minecraftOfficialLaunchCommand`, new `minecraftClientLaunchCommand` ids.
2. Backend: setup process, wizard client persisted, Edit client readback/save,
   launch override resolution and the official-launch process chain.
3. QML: Edit dialog client dropdown, join-bar picker, Hyprland keybindings
   (load the `omarchy` skill before editing anything under `~/.config`).
4. Tests, checks, live verify on scratch targets only, version bump, commit.

## Risks

- Seeding reads Trash once to keep Controlify. If it is emptied first, setup
  generates the vanilla 26.3 + Fabric template from scratch instead of blocking
  a launch; the generated recipe is covered by a test.
- The official launcher cannot auto-join; the UI must say it opens to the main
  menu with the server listed.
- A server named like a reserved instance would collide; the id helper refuses.
- Keybinding edits need `omarchy plugin validate` and a shell reload by Elena.

## Done when

Both keybindings and the Servers join bar work from the new template, the
wizard/Edit client choice survives a restart, the join picker overrides it for
one launch, the official path lists the server on open, all checks pass, and
the change is pushed.

## Verification

- `uvx pytest -q`: 740 passed.
- `/usr/lib/qt6/bin/qmllint` on the changed QML files: exit 0, no errors
  (baseline `Color`/`Style` warnings only).
- `omarchy plugin validate .`: exit 0. `git diff --check`: exit 0.
- `hyprctl reload` + `hyprctl configerrors`: both clean; both Minecraft
  keybindings still listed in `omarchy menu keybindings --print`.
- Scratch homes: setup is idempotent and seeds all three ids; per-server
  sidecars record the client choice; official `servers.dat` adds the new entry,
  keeps manual entries and does not duplicate on repeat.
- Pending: Elena reloads the shell and clicks through Remove, wizard success,
  Edit and the new client picker in the GUI.
