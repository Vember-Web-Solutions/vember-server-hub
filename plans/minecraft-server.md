---
node: minecraft-server
title: Minecraft server creation and controls in Gaming → Servers
status: active
created: 2026-11-19
tags: [gaming, docker, minecraft]
---

# Minecraft server creation and controls

## Goal

Let Elena create an `itzg/minecraft-server` container from Gaming → Servers, with
Paper as the default and Forge/Fabric selectable, then control and inspect it
from the same tab. Create one real Paper server on LAN port 25565.

## Scope

In:
- Pure model helpers for command construction, input validation, and detection.
- Panel state, creation/console process wiring, and notify-on-failure.
- A create form in Gaming → Servers plus Logs and Open data folder actions.
- Tests (model + structural guards), mutation verification, version bump.

Out:
- Modpack URLs / mod download automation. Forge and Fabric run as server types;
  adding mods is a manual step on the host afterwards.
- Bedrock (different image).
- Exposing RCON or editing `server.properties` from the hub.

## Steps

1. `Docker.mjs`: `normalizeMinecraftServerOptions(opts)` (allowlist type
   VANILLA/PAPER/FORGE/FABRIC, memory, version, name, data dir, port),
   `createMinecraftServerCommand(opts)` and `logsCommand(name, lines)`.
2. `Panel.qml`: form drafts, busy/status/result properties, create + logs
   processes with cancel, success refresh of Docker/games, notification.
3. `GamesTab.qml`: create form above the server list, type selector, Logs and
   Open data folder actions on each server row. Existing keyword detection
   already catches `vember-minecraft` / `itzg/minecraft-server`, so it stays.
4. Tests, mutation checks, full suite, qmllint, validate, version bump, commit.
5. Create the real Paper server and verify it appears with working controls.

## Risks

- Port 25565 already in use: guard before creating, report clearly.
- Container name collision: validate and surface the docker error.
- `docker run -d` returns fast; the container may still be downloading its
  server jar. Status must say "created, starting" rather than "ready".
- Forge/Fabric first start is slow. Do not add a stall timer.
- Never put secrets in config; RCON port stays unexposed.

## Done when

A Paper container named `vember-minecraft` is running with `/mnt/games/MinecraftServer`
mounted at `/data` and 25565 published, it appears in Gaming → Servers,
Start/Stop/Restart/Logs work, and all checks pass.
