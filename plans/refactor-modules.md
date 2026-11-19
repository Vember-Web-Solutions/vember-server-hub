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
  field blank; arrays and `null` now count as corrupt.
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
  were discarding the daemon's own reason, leaving only "(code 1)".
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

## Done when

`pytest` passes, `qmllint` reports no errors, and the panel opens with no
plugin warnings in the journal.

## Result

- 339 tests pass; `qmllint` reports no errors; `omarchy plugin validate` passes.
- Plugin source went 7,718 → 8,395 lines. The growth is comments, per-file
  headers and the one-line wrappers that keep call sites stable; the code that
  moved into `model/*.mjs` (1,310) and `ui/` (4,173) was already there.
- The three monoliths went 7,694 → 2,888 lines: `HubPanel.qml` 4,376 → 407,
  `HubModel.js` 825 → 0, and `Panel.qml` 2,493 → 2,481. The largest file is now
  `Panel.qml` at 2,481, then `ui/tabs/GamesTab.qml` at 803.
- The test suite is 2,162 lines across 11 files and drives the real modules
  through node, so it exercises the same code the shell runs.
- Version 0.1.0 → 0.5.0, build 72 → 75.
