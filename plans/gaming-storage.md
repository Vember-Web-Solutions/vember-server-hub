---
node: gaming-storage
title: Servers sub-tabs and game server storage sizes
status: done
created: 2026-11-19
tags: [gaming, storage, docker]
---

# Servers sub-tabs and game server storage sizes

## Goal

Move the Minecraft create form out of the Servers list into its own tab, give
logs their own tab, and report how much space each detected game server uses
under Gaming → Storage. Elena chose three sub-tabs (Servers / Create / Logs)
and both size figures (data folder and container/image).

## Scope

In:
- `serversSubTab` in GamesTab.qml with three buttons and `visible:` gates on the
  existing list, form and log viewer. Row Logs actions open the Logs tab.
- A pure model helper for game-server detection, shared by Servers and Storage.
- A size command + parser that reports the host data folder (`du -sh`) and the
  Docker container/image size (`docker ps -s`) for each server.
- Panel state/process, a Storage card with a Refresh button, tests, version bump.

Out:
- Deleting servers or editing server.properties.
- Streaming live logs; Logs remains a fixed 200-line snapshot.
- Sizes for Steam client games; only dedicated servers with an install dir count.

## Steps

1. `model/Gaming.mjs`: `gameServerContainers(list, steamServers)` (the keyword
   list moved out of QML), `gameServerSizeCommand(servers)`,
   `parseGameServerSizes(text)`.
2. `ui/tabs/GamesTab.qml`: sub-nav, visibility gates, Logs navigation, Storage
   card that refreshes sizes when it becomes visible.
3. `Panel.qml`: size state, process, `refreshGameServerSizes()`, expose sizes in
   `status()` for live verification.
4. Tests in `tests/test_gaming.py` and `tests/test_qml_structure.py`; mutate,
   run full suite, qmllint, plugin validate, version bump, commit.
5. Live verify the size output and the tab wiring; write a save point.

## Risks

- `du -sh` on a large world can take seconds. It runs only when Storage opens,
  and a manual Refresh is available; never on the 15s poll.
- Container names come from Docker; pass them as positional args to `sh -c`,
  never interpolated into the script text.
- Moving detection to the model must preserve the exact keyword list, or rows
  will disappear from the Servers tab.
- The Logs tab must be selected by the row Logs action, or clicking it appears
  to do nothing.

## Done when

Gaming → Servers has Servers / Create / Logs sub-tabs that each show the right
block; Gaming → Storage lists the detected game servers with both sizes; all
checks pass and the changes are pushed.
