---
node: minecraft-direct-launch
title: One-click Minecraft client launch into the Vember server
status: active
created: 2026-11-20
tags: [minecraft, prism, gaming, hyprland]
---

# One-click Minecraft client launch

## Goal

Give Elena two one-click paths from the hub (and two keybindings): one that
launches the game already joined to `vemberos:25565`, and one that launches the
same clean client to the main menu.

## Scope

In:
- Two clean vanilla 26.3 Prism Launcher instances (no mods) on this machine:
  `vemberos-vanilla` (main menu) and `vemberos-server` (join on launch).
- Hub model helper that builds the `prismlauncher --launch <instance>` argv.
- Two buttons in Gaming → Servers and two Hyprland keybindings.
- Tests, version bump, live verification, commit and push.

Out:
- Changing the official launcher's Quick Play tile.
- Touching the modded Create: Astral instance.
- Any change to the running Minecraft server.

## Decisions

- Two vanilla instances share the same game files: `vemberos-vanilla` opens to
  the main menu, `vemberos-server` has `JoinServerOnLaunchAddress=vemberos:25565`.
- Prism's `--server` CLI flag logs the address but does not pass it to 26.3's
  game arguments, so the address lives in the join instance instead. This was
  verified live: the game logged `Connecting to vemberos, 25565` from the
  instance setting; the CLI flag never produced a connection attempt.
- Instance ids are constants in the model, like the existing machine-specific
  defaults. No new config surface for two fixed values.
- Buttons reuse the existing launch Process pattern and `handOffToExternalSurface()`.

## Steps

1. Create both vanilla Prism instances and verify the join instance connects.
2. Model helper + tests for both command shapes.
3. Panel launch function/process + status exposure.
4. Two buttons in GamesTab Servers sub-tab; structural guards.
5. Two Hyprland keybindings in `~/.config/hypr/bindings.lua`, validated.
6. Full checks, live hub verification, version bump, commit and push.

## Risks

- Prism auto-selects Java 25 for 26.3 and downloads it on first launch; the
  first start can take ~100s before a window appears.
- Repeated test launches can trip Mojang's session-server rate limit (HTTP 429),
  which blocks the join even though the client reaches the address. Avoid
  repeated launches in a short window; wait before re-testing authentication.
- A bad QML binding passes qmllint but fails live — check the journal after restart.

## Done when

Both hub buttons and both keybindings start the clean 26.3 client, the join
variant reaches `vemberos:25565` (verified from the game log; a live player-list
check was blocked by a temporary Mojang 429 during verification), all checks
pass, and the change is pushed.
