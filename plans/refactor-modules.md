---
node: refactor-modules
title: Class-based model and modular QML
status: done
created: 2026-11-18
tags: [refactor, modules, tests, qml]
---

# Class-based model and modular QML

## Goal

Break the plugin's two monoliths (`model/HubModel.js`, `HubPanel.qml`) into
named, single-purpose files without changing behaviour, and put a test suite
under the model layer so future breakage is caught before it reaches the shell.

## Scope

**In:** model split into ES class modules, QML tabs and overlays extracted into
their own files, pytest suite driving the real modules through node.

**Out:** rewriting `Panel.qml`'s `Process`/`Timer` wiring into separate
controllers. That file is stateful and the objects reference each other by id;
it is the next candidate, not part of this node.

## Steps

1. Record line counts before touching anything.
2. Prove the runtime can load ES module classes (`_probe.mjs` in `BarWidget.qml`, journal check).
3. Split `HubModel.js` into `Shell`, `InstallLog`, `Docker`, `Systemd`, `SystemInfo`,
   `Tailscale`, `Gaming`, `DevTools`, `Ssh`, `Omarchy`.
4. Differential-test all 65 functions against the original implementation.
5. Rewrite QML call sites to the new namespaces; watch each module for hot reload.
6. Extract the five tab bodies into `ui/tabs/`, then the nine dialogs into `ui/`.
7. Move the pure parsers left in `Panel.qml` (`parseSize`, pull progress, tab order)
   into `Docker` and `Config`.
8. Write the pytest suite; verify the panel opens with a clean journal.

## Risks

- QML resolves component names only from the same directory or an explicit
  `import`, so extracted files need `import "ui/tabs"` / `import "ui"`.
- Relative model imports are resolved from the importing file, so files one
  level down need `../model/`, two levels down `../../model/`.
- A component cannot see the enclosing file's `id`s: anything referenced across
  the boundary must become a property (`panel`, `cardRadius`).
- QML ids are not properties of the root — never write `root.<id>`.

## Follow-on hardening

Work that fell out of the split, done in the same arc:

- **Packaging:** `omarchy plugin validate` rejects symlinks anywhere inside a
  plugin folder, and a venv is nothing but symlinks. The test environment moved
  to `~/.cache/vember-server-hub/venv`, created on demand by `tests/run.sh`.
- **CI:** `.github/workflows/tests.yml` runs the suite on push and PR.
- **Hot reload:** fifteen hand-written watchers became one `Instantiator` over a
  `watchedFiles` list, now covering `ui/*.qml` and `ui/tabs/*.qml`. Editing a
  tab used to do nothing until the shell was restarted by hand.
- **Config parsing:** `Config.parseHubConfig` returns `empty` / `ready` /
  `wizard` / `invalid`, replacing ~45 lines of branching in a stream handler.
  Testing it found that `JSON.parse("[]")` produced a "valid" config with every
  field blank; arrays and `null` now count as corrupt. `Config.parseManifest`
  parses `manifest.json` into the manifest the version binds to. Both readers
  are wired to these parsers; static guards keep `configReadProc` on
  `parseHubConfig` and `manifestReadProc` on `parseManifest`, because the
  refactor had crossed them — the manifest was being parsed as a config, which
  reopened the first-run wizard and blanked the server name in a startup race.
- **Tab table:** `Config.tabDef` / `orderedTabs`, so labels and icons are one
  table rather than a chain of `if`s in QML.
- **Colours and counts:** `Docker.stateTone` / `stateBackground` /
  `runningCount`, `Tailscale.onlinePeerCount`, `SystemInfo.storageUseColor`.
  The 75%/90% storage thresholds are now tested at their boundaries.
- **Static guards:** tests cover balanced braces, relative imports that exist,
  `panel.<helper>()` calls that resolve, `hub.<member>` references that resolve,
  required properties supplied at every instantiation site, no `root.<id>`, and
  the manifest and `Panel.qml` version fallback agreeing.
- **Interactive installs:** a pty test runs the real generated script against a
  stub terminal and types an answer, which is the failure that started this.
- **Failure reporting:** `Shell.failureMessage` folds the first meaningful
  stderr line into an action's failure message. Docker and Code Server actions
  were discarding the daemon's own reason, leaving only "(code 1)". The same
  gap was closed for Docker pulls (keeps the last output line), repo-detail
  loads (git's stderr) and Tailscale actions (polkit/tool stderr), so each
  failure says what actually went wrong.
- **Manifest guard:** tests check the manifest's required fields, that its
  entry points exist and are of known kinds, that its id matches the plugin
  paths hardcoded in QML, and that the version is semver with an integer build.
  These need no Omarchy install, so they also run in CI.
- **One tab order:** the default order was written out three times; it now
  lives only in `Config.mjs`, and the arrange dialog's swap is `Config.moveTab`
  (a pure function that returns a new array and treats an off-end move as a
  no-op).
- **One container name:** `DevTools.codeServerContainer` /
  `codeServerConfigDir` are the only source for the code-server container and
  its config directory, which were spelled out a dozen times in `Panel.qml`.
- **Atomic config write:** `Config.writeCommand` writes `config.json` to a
  sibling temp file and renames it into place, so a crash cannot leave a
  truncated file that parses as corrupt and blanks every setting. The payload
  is passed as its own argument, never interpolated into the shell string.
- **Install watchdog:** closing the terminal midway used to strand the panel on
  "running" forever — the log had output, the `tail -F` never ended, and no
  exit marker was written, while the watchdog bailed out as soon as the log was
  non-empty. Liveness now comes from the lock file's pid, checked on a
  repeating timer regardless of log content, and the reattach path starts it
  too. `InstallLog.watchdogVerdict` / `lockCheckCommand` put the branch decision
  and the shell check in the model layer, tested by running the command against
  real lock files. The Omarchy update flow had the identical flaw and now has
  the same watchdog; its lock stores the pid on line 1 rather than line 2.
- **Docker pull failures:** the last output line is kept and folded into the
  result, so a failed pull says why (bad tag, no space, network) instead of only
  "(code 1)".
- **Poll safety:** `refreshAll()` runs on the 15-second poll while the panel is
  open, and it used to do destructive work every tick. `refreshDev()` cleared
  the selected repository and its detail panel, so a repo being inspected was
  deselected every 15 seconds; `refreshGames()` blanked the game counts and the
  dedicated-server list, and killed and restarted the extra-apps scan, which
  never finishes if it runs longer than the interval. The poll now passes
  `preserveSelection` and the scan starts only when none is in flight. Opening
  the panel and post-install refreshes still do the full reset.
  `TestPollSafety` pins all three, mutation-verified.
- **One-shot messages:** `tsActionProc.onExited` wrote the Tailscale action
  result and then called `refreshTailscale()`, which cleared the note in the
  same tick — a failed action looked identical to a successful one.
  `refreshTailscale` now takes a preserve flag the action handler sets.
- **Code Server double start:** the setup dialog disabled its button while
  busy, but the function itself started a second flow if called again; it now
  guards on `codeServerBusy` so the flag is authoritative.
- **Docker pull progress:** the panel pull parsed an `NN%` string that Docker's
  non-TTY output does not emit, so the bar sat at zero. It now accumulates
  layer bytes through the same `Docker.parsePullLine` / `accumulateLayers` path
  the code-server pull uses.
- **Poll safety, round two:** more of the same class. `refreshGames()` restarted
  the Steam manifest scan and force-reloaded the library VDF every tick (the
  VDF reload restarted the scan again), so a slow scan never settled; the scan
  now starts only when idle and the VDF is reloaded only on a full refresh.
  `refreshDev()` restarted `devToolsProc` unconditionally, killing the
  `devTools → devRepos → codeServer` chain mid-flight — a slow repo `find`
  never finished and `devRepos` stayed stale. The poll path now starts the
  chain only when none of it is in flight. `TestSteamScanPollSafety` and the
  `refreshDev` chain guard pin both, mutation-verified.
- **Container size flicker:** `hub.dockerContainers` is reassigned to fresh
  objects every poll, so the detail panel's `selected` object changed identity
  each tick and `onSelectedChanged` re-ran `docker ps -s`, blanking the size to
  "Querying…" every 15 seconds. The query now keys off the container name.
  `TestDockerDetailPollSafety` pins it.
- **Dead targeted-refresh flag:** `devToolsOnlyRefresh` was declared and read
  but never set, so `refreshDevTools()` silently did a full repo rescan after
  every tool install, and the flag was cleared before the status message could
  read it. It now sets the flag, leaves it for `codeServerProc` to read and
  clear at the end of the chain, and the install handler no longer restarts
  `codeServerProc` by hand. `TestDevToolsTargetedRefresh` pins it.
- **Dead state and wasted poll work:** a dead-state sweep found seven properties
  assigned but never read: `gameMountSummary`, `dockerPullingImage`, `bnetNote`,
  `sshHostKeys`, `tailscaleStatusText`, `restartingForServerName` and
  `targetLineNo`. Two of them were fed by processes — `tsStatusProc`
  (`tailscale status`) and `sshHostKeysProc` (`ssh-keygen -lf`) — that ran real
  shell-outs on every 15s poll while nothing displayed the result, so the cost
  was two extra processes per tick, not just clutter. All removed. `steamNote`
  was computed but never shown; it now captions the Steam count. A new
  `TestNoDeadProperties` fails if any property is declared but never read,
  mutation-verified.
- **Stopped installs left stale counts:** `finishInstall` schedules the
  post-install refresh (`installRefreshTimer` / `installRefreshTimer2`) so game
  and dev counts update. `stopInstall`, which the "dead" watchdog verdict calls
  when a terminal closes mid-install, did not, so the panel kept pre-install
  counts forever because nothing else re-scans. `stopInstall` now schedules the
  same refresh; `TestInstallWatchdog::test_stop_install_refreshes_counts_like_finish`
  pins it.

## Done when

`pytest` passes, `qmllint` reports no errors, and the panel opens with no
plugin warnings in the journal.

## Result

- 380 tests pass; `qmllint` reports no errors; `omarchy plugin validate` passes.
- Plugin source went 7,718 → 8,545 lines. The growth is comments, per-file
  headers and the one-line wrappers that keep call sites stable; the code that
  moved into `model/*.mjs` (1,368) and `ui/` (4,179) was already there.
- The three monoliths went 7,694 → 2,974 lines: `HubPanel.qml` 4,376 → 407,
  `HubModel.js` 825 → 0, and `Panel.qml` 2,493 → 2,567. `Panel.qml` grew by the
  two install/update watchdogs, the failure-message improvements and the poll
  guards, then lost the duplicated config-parsing branch once the reader was
  wired to the tested parser and shed the dead state found in the audit; the
  largest file is now `Panel.qml` at 2,567, then `ui/tabs/GamesTab.qml` at 803.
- The test suite is 2,808 lines across 11 files and drives the real modules
  through node, so it exercises the same code the shell runs.
- Version 0.1.0 → 0.6.4, build 72 → 80.
