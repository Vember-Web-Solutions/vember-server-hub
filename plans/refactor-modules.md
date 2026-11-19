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
- **Known limitation (not fixed):** `codeServerSetupProvisionProc` has no
  timeout, and both `setupCodeServerTerminal` and `uninstallCodeServer` return
  early while `codeServerBusy`. A genuinely hung `docker exec` would leave the
  Code Server UI busy until a shell restart. Not fixed because a stall timer
  that fired during a legitimately slow image pull or provisioning run would
  report a false failure — the same bug class the rest of this work guards
  against — and the hang path could not be exercised end to end here without
  pulling the full image and running real provisioning.
- **Live verification needs exactly one shell.** `omarchy-launch-shell` is a
  supervisor: it relaunches `quickshell` after a non-zero exit and only stops
  when the wrapper itself gets TERM. Killing `quickshell` alone leaves the
  wrapper to respawn it, so rapid or overlapping `omarchy restart shell` calls
  can accumulate several shells. Each orphan keeps whatever it was drawing —
  including the hub overlay — so a layer count taken with more than one shell
  running reads high and looks like a regression. Check `pgrep -x quickshell |
  wc -l` is 1 before trusting `hyprctl layers`. This bit during this work: a
  stale 3/4/3 layer count turned out to be five orphaned shells, and the same
  measurement with one shell was a clean 0/1/0. It is an Omarchy restart race,
  not this plugin, but it makes the plugin's live check unreliable if ignored.

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
- **Optimistic editor-launch status:** `openAuthorizedKeysEditor` set "Opened
  authorized_keys in editor." the moment the launch was requested, and
  `sshAuthorizedKeysEditorProc` had no `onExited` handler. If
  `omarchy-launch-editor` was missing or failed, the user was told it opened
  when nothing happened. The status now comes from the exit code — success on 0,
  `Shell.failureMessage` with the stderr otherwise, plus a hint to edit the file
  directly. `TestEditorLaunchFailure` pins it.
- **Container selection drifted on poll:** the container detail panel tracked
  its selection by list index (`selectedContainerIndex`). The 15s poll
  reassigns `hub.dockerContainers` and can reorder it — a container created at
  the top shifts every index down — so an index-based selection silently
  pointed at a *different* container, and the detail panel's actions (including
  Remove) targeted the wrong one. Selection is now keyed by container name and
  the detail's `selected` is looked up by name. `TestContainerSelectionStability`
  pins it.
- **Silent launcher failures:** `steamLaunchProc` and `bnetLaunchProc` set a
  "Launching …" message and never inspected the exit code.
  `omarchy-launch-battlenet` exits 1 with a message when Battle.net is not
  installed, and a missing or failed binary is equally silent, so the user was
  left looking at a "Launching…" message with nothing happening. Both now
  surface a non-zero exit through `Shell.failureMessage`; a zero exit stays
  quiet because a launcher runs in the foreground until the app closes (and
  `steam` exits 0 immediately when it is already running).
  `TestLauncherFailureSurfacing` pins it.
- **SSH key removal could delete the wrong line:** `sshSelectedKeyIndex` was a
  writable list index, and `hub.sshAuthorizedKeys` is re-read every 15s. A key
  added above — or an external edit — shifts every index, so
  `removeSelectedAuthorizedKey` would read a *different* entry's `lineNo` and
  delete the wrong line from `authorized_keys`. That is data loss, not just a
  wrong detail panel. Selection now holds the stable `keyData` blob and
  `sshSelectedKeyIndex` is a readonly property derived from it, so every read
  site keeps working while removal targets the key the user actually chose.
  `TestSshKeySelectionStability` pins it.
- **Silent config-write failure:** `configWriteProc` only handled a zero exit.
  On a non-zero exit with empty stderr the previous status message stayed up, so
  the user believed their settings saved when the write had failed. The
  non-zero branch now surfaces through `Shell.failureMessage`, without
  overwriting the more specific message the stderr handler may already have set.
  `TestConfigWriteFailureSurfacing` pins it.
- **Unvalidated SSH key paste:** `addAuthorizedKey` appended whatever was
  pasted and reported "Key added." A private key, a multi-line blob or a typo
  would be written to `authorized_keys` and never authenticate — and a pasted
  private key would reach disk. `Ssh.validatePublicKeyLine` now rejects private
  keys, multi-line input, non-key text and bad base64, and the normalised key is
  what gets written. `TestValidatePublicKeyLine` covers the model;
  `TestSshAddKeyValidation` pins the wiring.
- **Dead exports:** each class method is exported twice (method plus hoisted
  `export function`) so QML can call `Module.name(...)`. Ten of those exports
  had no production caller at all — a superseded `Tailscale.statusCommand`, the
  old single-directory Steam manifest helpers, `SystemInfo.parsePgrepCount`, an
  unwired SSH host-key fingerprint pair, three unused `Shell` formatters, and
  the whole `Omarchy` module, whose update launch the panel had already
  replaced with one that writes the lock file, tees the log and focuses the
  terminal. Tests kept passing against them because a test is not a caller.
  All ten are gone (with their tests), and `TestNoDeadModelExports` now fails
  when an export has no production reference.
- **A focus call that never worked:** the install and update terminals were
  focused with `hyprctl dispatch focuswindow 'class:^(vember-install)$'`. On
  Hyprland 0.56 `dispatch` is a Lua entry point, so that argument is a syntax
  error: the call failed every time, behind `|| true`. Two things were wrong,
  and the second is the one that mattered to a user:
  1. The supported form is a dispatcher object,
     `hyprctl dispatch 'hl.dsp.focus({window="class:vember-install"})'`. It
     exits 0 whether or not it found a window (a miss prints "window not
     found"), so success has to be read from the output — an `||` chain stops
     on the first selector and never tries the fallbacks. `model/Hypr.mjs`
     builds that snippet and keeps the legacy form as a fallback for older
     builds.
  2. The hub is a full-screen overlay with exclusive keyboard focus. Even a
     correct focus call cannot land while it is open, and the terminal sits
     behind the backdrop, which swallows clicks. The terminal was therefore
     unreachable — and an install terminal whose sudo prompt cannot be reached
     is not a fix. Every path that opens an interactive terminal now closes the
     hub first; the log keeps streaming to disk and reopening the hub
     reattaches to the running install or update.
  `TestFocusScript`, `TestFocusByClassScript` and
  `TestExternalHandOffReachability` pin both halves.
- **The same overlay problem for every other hand-off.** Closing the hub was
  not only about terminals: anything the panel launches lands behind a
  full-screen overlay whose backdrop swallows clicks, so an editor, a browser
  page or a game launcher looked like a dead button. Every action that hands
  off to a surface outside the hub now goes through one helper,
  `handOffToExternalSurface()`, so the rule lives in one place and the guard
  can check the set rather than two functions: installs, the Omarchy update,
  Tailscale actions, the authorized_keys editor, the code-server browser tab,
  the Battle.net setup page, Steam, Battle.net, extra app launchers and opening
  a repo in an editor. The guard also fails if a launch path closes the hub by
  hand instead of through the helper, since that would satisfy the user and
  hide from the check.
  Reopening mid-install was the one regression this could cause: `refreshAll()`
  cleared the status line on open, which would blank the only sign of a running
  install now that opening the hub is what a user does to check on it. The
  clear is skipped while an install or update is running.
- **Closing the hub made launch failures silent.** The status line a failed
  launch writes was the only report, and it now lands in a panel nobody is
  looking at — so a launch that failed would look exactly like a button that
  does nothing. The five hand-off paths whose failure the user must know about
  (Steam, Battle.net, extra app launchers, opening a repo in an editor, the
  authorized_keys editor) now also raise a desktop notification through
  `Shell.notifyCommand`, which builds argv for `omarchy-notification-send` at
  normal urgency so it respects the desktop's silencing. `TestNotifyCommand`
  and `TestLaunchFailureIsVisible` pin the shape and the wiring.
- **The watchdog messages had the same problem.** "Could not open the install
  terminal", "the terminal closed before finishing" and "no output yet, it may
  be asking for a password" are all reported after the hub has closed itself,
  which is precisely when the user is not looking at the panel. All three
  watchdog branches (install, update, and the no-output nudge) notify as well.
  `TestWatchdogFailuresAreVisible` counts the notify calls per block, because
  the first version only asked whether a notify existed at all and a block with
  two failure branches still passed after one was removed.
- **The launcher's exit status was a false failure signal.** The install
  wrapper backgrounds the terminal and then runs the focus snippet, so the
  script's exit status was the *focus* snippet's. With `hyprctl` missing, the
  snippet returned 1 and `installTerminalProc` read that as "the terminal never
  opened" — then called `finishInstall(null)` and stopped tracking a real
  install. Two fixes: the focus snippet now ends with `|| true` so it can never
  fail the launcher, and the terminal-launch handler no longer stops tracking
  on a non-zero exit at all. Only the lock file and the log can tell a missing
  terminal from a slow one, so the watchdog owns that verdict.
- **`Qt.openUrlExternally` returns a bool and both call sites ignored it.**
  With no browser handler configured, the call returns false, the hub closed
  anyway, and nothing opened — the dead-button problem again. Both the
  code-server URL and the Battle.net setup page now check the return value,
  keep the hub open on failure and notify.
- **One helper now owns the browser hand-off.** `openExternalUrl(url, what)`
  checks the `Qt.openUrlExternally` result, notifies on failure and returns a
  bool; the code-server and Battle.net hand-offs use it, and the two Docker Hub
  links in the Containers tab did not check at all — they do now. A static guard
  fails if any file under `ui/` calls `Qt.openUrlExternally` directly, so the
  check cannot drift back out of the helper.
- **Notifications were dropped when two arrived close together.** `notify()`
  reused one Process — set `running = false`, changed the command, started it
  again — so a second notification killed the first mid-send. With the hub
  closed, the notification is the only feedback, so a dropped one is invisible.
  Notifications now queue and drain one at a time on `onExited`.
  `TestNotificationsAreQueued` pins the queue, the running guard and the drain.
- **The post-install refresh could clobber a new install.** `refreshAfterInstall`
  runs 2.5s and 9s after an install finishes. A new install started inside that
  window would get a full games reset while it streamed, blanking the counts
  until the scans caught up. It now skips while an install is running; the new
  install refreshes on its own finish.
- **The dev-tools refresh could be lost to an overlapping install.** The
  post-install refresh used to re-derive "was this a dev install" from
  `installRunningId`. A dev install followed within the 2.5s/9s window by an app
  install replaced that id, so the tools never rescanned and the Dev tab kept
  showing a stale tool. The finish and stop paths now set `devRefreshPending`,
  and the refresh consumes it.
- **The panel was destroyed when the hub closed, so its watchdogs and
  notifications never ran.** The shell's Loader activates a panel while
  `keepLoaded` is set or the panel id is in `openPanelIds`; the manifest set
  neither, so `shell.hide()` unloaded the panel and took every Process and
  Timer with it. Every failure notification added for a post-hand-off failure
  (a failed launch, an install or update watchdog verdict) was therefore dead
  code — it could only fire while the panel was still open, which is never when
  those failures happen. Verified directly: `omarchy-shell shell call <id>
  status` returned the panel's JSON while open and `unknown` after `hide`. The
  manifest now sets `"keepLoaded": true`; `HubPanel.qml` already binds
  `visible: hub.opened` and drops keyboard focus when closed, so the panel
  stays loaded but hidden. `TestManifest::test_panel_is_keep_loaded` pins both
  halves.
- **A background action could fail into a closed panel.** A Docker pull takes
  minutes and a stop can take ten seconds; the user can start one and close the
  hub before it finishes. Its failure only set `lastActionMessage` (a toast) or
  a result field, neither visible while the panel is closed. `notifyIfClosed()`
  now raises a desktop notification when the panel is closed and stays quiet
  when it is open, applied to the Docker action, pull and prune failures and to
  the Code Server start/stop/uninstall failure.
  `TestBackgroundActionFailuresAreVisible` pins the helper and each branch.
- **A QML file could call a model function that no longer exists.** The model
  layer is imported per file with an alias (`import "model/Shell.mjs" as
  Shell`), so `Shell.trim(...)` resolves only if Shell.mjs exports `trim`. A
  typo or a missed rename fails at runtime in whichever tab renders that line,
  with no compile-time warning. `TestNoDeadModelExports` covered the other
  direction only. `TestModelReferencesResolve` now checks every `Alias.member`
  call against that module's exports (skipping the `watchedFiles` path strings),
  and carries an in-memory mutation check.
- **keepLoaded made the panel's timers a login-time cost.** With the panel
  instantiated at shell start, the plugin update startup check (a `git fetch`
  against GitHub) would run on every login for a panel the user may never open.
  Before keepLoaded the panel was built on first open, so that timer naturally
  fired 4s after opening. It is now gated on `root.opened`, restoring the
  original behaviour. `TestNoLoginTimeWork` pins it and also fails on any
  unconditional `Timer` in `Panel.qml`.
- **keepLoaded let transient dialog state survive a close.** Before, closing
  the hub destroyed the panel and every property with it. Now the panel is
  unloaded-but-alive, so a confirm dialog left open, the settings menu, or a
  typed Code Server password persisted across a close/open cycle. The password
  is the one that matters: it is cleared only after a successful submit, so a
  password typed and then abandoned would sit in memory for the rest of the
  session and be redisplayed on the next open. `HubPanel.resetTransientState()`
  runs from `onVisibleChanged` when the panel hides and clears the three
  confirm flags, the password, the settings menu and the arrange-tabs dialog.
  `TestTransientStateIsClearedOnClose` pins the hook and each property.
- **A config read failure looked like a first run and trapped the user.** The
  read command was `[ -f "$1" ] && cat "$1"`, so a file that exists but could
  not be read produced empty output. That parsed as "empty" and opened the
  first-run wizard — and at startup `configReady` is false, so that wizard has
  no Cancel button, leaving Save as the only way out, which would overwrite a
  good config with the hostname. `Config.readCommand()` now emits a marker for
  a missing or unreadable file and `Config.readOutcome()` classifies it; an
  unreadable file keeps the current state and notifies instead of opening the
  wizard. `TestConfigRead` runs the real command against a missing, an
  unreadable and a readable file; `TestConfigReadFailureIsVisible` pins the
  handler.
- **A plugin self-update could fail into a closed panel.** The update dialog
  runs in the panel, but the user can close the hub while the `git fetch` or
  `git pull` is in flight. Both failure branches only set `pluginUpdateStatus`,
  which is invisible once the panel is closed, and the success branch's
  "complete, now reload" is an action the user would never learn about. Both
  plugin-update processes now call `notifyIfClosed()`; the success line also
  lost a dead `? "" : ""` ternary.
  `TestBackgroundActionFailuresAreVisible` covers both failure branches and
  the completion notice.
- **Install and update could run at once, and focus could land on the wrong
  one.** Both terminals use the `vember-install` window class — that class is
  what the focus step selects on — and neither entry point checked the other.
  Starting an update while an install ran gave two matching windows, so focus
  went to whichever mapped first and the other terminal's prompts were missed.
  Both entry points now refuse while the other is running, and every button
  that starts one is disabled while the other runs — a button that stays
  enabled and quietly does nothing is the same dead-button problem.
  `TestMutualExclusionIsVisible` pins the gating; it matches the calls that
  start an install specifically, since `hub.installLog` and `hub.installRunning`
  appear throughout the log panel and a looser pattern caught the Clear button.

## Done when

`pytest` passes, `qmllint` reports no errors, and the panel opens with no
plugin warnings in the journal.

## Result

- 475 tests pass; `qmllint` reports no errors; `omarchy plugin validate` passes.
- Plugin source went 7,718 → 8,831 lines. The growth is comments, per-file
  headers and the one-line wrappers that keep call sites stable; the code that
  moved into `model/*.mjs` (1,389) and `ui/` (4,192) was already there.
- The three monoliths went 7,694 → 3,201 lines: `HubPanel.qml` 4,376 → 424,
  `HubModel.js` 825 → 0, and `Panel.qml` 2,493 → 2,777. `Panel.qml` grew by the
  two install/update watchdogs, the failure-message improvements and the poll
  guards, then lost the duplicated config-parsing branch once the reader was
  wired to the tested parser and shed the dead state found in the audit; the
  largest file is now `Panel.qml` at 2,777, then `ui/tabs/GamesTab.qml` at 803.
- The test suite is 4,119 lines across 12 files and drives the real modules
  through node, so it exercises the same code the shell runs.
- Version 0.1.0 → 0.6.29, build 72 → 105.
