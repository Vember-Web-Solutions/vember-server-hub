"""Structural checks for the QML layer.

The panel is now spread across HubPanel.qml, ui/*.qml and ui/tabs/*.qml. These
tests catch the mistakes that split actually produced while it was being built:

  - a component used without an import, so QML says "<name> is not a type"
  - a relative model import pointing at a file that does not exist
  - `panel.<helper>()` naming a helper that HubPanel.qml no longer defines
  - `root.<id>` — QML ids are not properties of the root object

They are static: no shell, no Qt, so they run anywhere.
"""

import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]

QML_FILES = sorted(
    [REPO / "Panel.qml", REPO / "HubPanel.qml", REPO / "BarWidget.qml"]
    + list((REPO / "ui").glob("*.qml"))
    + list((REPO / "ui" / "tabs").glob("*.qml"))
)


def read(path):
    return path.read_text()


def relative(path):
    return str(path.relative_to(REPO))


class TestBraces:
    @pytest.mark.parametrize("path", QML_FILES, ids=relative)
    def test_braces_balance(self, path):
        text = read(path)
        assert text.count("{") == text.count("}"), "unbalanced braces in " + relative(path)


class TestImports:
    @pytest.mark.parametrize("path", QML_FILES, ids=relative)
    def test_relative_imports_exist(self, path):
        for target in re.findall(r'^import "([^"]+)"', read(path), re.M):
            if not target.startswith("."):
                continue
            resolved = (path.parent / target).resolve()
            assert resolved.exists(), "%s imports missing %s" % (relative(path), target)

    @pytest.mark.parametrize("path", QML_FILES, ids=relative)
    def test_component_imports_cover_ui_usage(self, path):
        """A file that uses a ui/ component must import the directory."""
        text = read(path)
        used = set(re.findall(r"^\s*([A-Z][A-Za-z0-9]*(?:Tab|Dialog|Menu|Stack|Wizard))\s*\{", text, re.M))
        if not used:
            return
        # Components live in ui/ or ui/tabs/, so one of those must be imported.
        assert re.search(r'^import "(?:\.\./)*ui(?:/tabs)?"', text, re.M), (
            "%s uses %s but imports no ui directory" % (relative(path), sorted(used))
        )


class TestHubPanelHelpers:
    """ui/** calls shared helpers on the panel root; they must still exist."""

    @staticmethod
    def _helpers():
        text = read(REPO / "HubPanel.qml")
        return set(re.findall(r"^  function ([A-Za-z_][A-Za-z0-9_]*)\(", text, re.M))

    def test_called_helpers_are_defined(self):
        helpers = self._helpers()
        assert helpers, "no functions found in HubPanel.qml"
        problems = []
        for path in QML_FILES:
            if path.name == "HubPanel.qml":
                continue
            for name in re.findall(r"(?<![\w.])panel\.([A-Za-z_][A-Za-z0-9_]*)\(", read(path)):
                if name not in helpers:
                    problems.append("%s calls panel.%s()" % (relative(path), name))
        assert not problems, "undefined helpers:\n  " + "\n  ".join(problems)

    def test_every_ui_file_declares_the_panel_property(self):
        missing = []
        for path in list((REPO / "ui").glob("*.qml")) + list((REPO / "ui" / "tabs").glob("*.qml")):
            text = read(path)
            if re.search(r"(?<![\w.])panel\.", text) and "required property var panel" not in text:
                missing.append(relative(path))
        assert not missing, "ui files using panel. without declaring it:\n  " + "\n  ".join(missing)


class TestNoRootIdAccess:
    """`root.<id>` is always a runtime TypeError: ids are not root properties."""

    @pytest.mark.parametrize("path", QML_FILES, ids=relative)
    def test_root_does_not_reference_local_ids(self, path):
        text = read(path)
        ids = set(re.findall(r"^\s*id: ([A-Za-z_][A-Za-z0-9_]*)", text, re.M))
        if not ids:
            return
        bad = sorted(i for i in ids if re.search(r"\broot\." + re.escape(i) + r"\b", text))
        assert not bad, "%s uses root.<id>: %s" % (relative(path), bad)


class TestNoStaleModelReferences:
    @pytest.mark.parametrize("path", QML_FILES, ids=relative)
    def test_hubmodel_is_gone(self, path):
        text = read(path)
        assert "HubModel." not in text, relative(path) + " still calls the removed HubModel"


class TestVersionConsistency:
    """The version shown in the panel must match manifest.json.

    The panel reads manifest.json at load, but falls back to a literal while
    that read is in flight. A stale literal showed "v0.1.0" on a 0.4.0 build,
    so the two records are pinned together here.
    """

    @staticmethod
    def _manifest():
        import json

        return json.loads((REPO / "manifest.json").read_text())

    def test_manifest_has_version_and_build(self):
        manifest = self._manifest()
        assert isinstance(manifest.get("version"), str) and manifest["version"]
        assert isinstance(manifest.get("build"), int)

    def test_panel_fallback_matches_manifest(self):
        import re

        manifest = self._manifest()
        text = read(REPO / "Panel.qml")

        version = re.search(r'pluginVersion:.*?:\s*"([^"]+)"', text)
        build = re.search(r"pluginBuild:.*?:\s*(\d+)", text)
        assert version, "no pluginVersion fallback literal in Panel.qml"
        assert build, "no pluginBuild fallback literal in Panel.qml"
        assert version.group(1) == manifest["version"], (
            "Panel.qml falls back to %s but manifest.json says %s"
            % (version.group(1), manifest["version"])
        )
        assert int(build.group(1)) == manifest["build"]

    @pytest.mark.parametrize("path", QML_FILES, ids=relative)
    def test_no_hardcoded_version_strings(self, path):
        import re

        # A bare 0.x.y literal in QML means someone hardcoded a version that
        # will go stale. The one allowed literal is the declared fallback in
        # Panel.qml, which test_panel_fallback_matches_manifest pins to the
        # manifest; anywhere else is drift waiting to happen.
        offenders = []
        for number, line in enumerate(read(path).splitlines(), 1):
            if re.search(r'"[0-9]+\.[0-9]+\.[0-9]+"', line) and "pluginVersion:" not in line:
                offenders.append("line %d: %s" % (number, line.strip()))
        assert not offenders, "%s hardcodes a version:\n  %s" % (
            relative(path),
            "\n  ".join(offenders),
        )

    def test_manifest_reader_parses_the_manifest_not_the_config(self):
        # manifest.json and config.json are different shapes. Feeding the
        # manifest to parseHubConfig returned state "wizard" and raced the real
        # config load, reopening the first-run wizard. The reader must use
        # parseManifest and only set root.manifest.
        text = read(REPO / "Panel.qml")
        start = text.index("id: manifestReadProc")
        window = text[start:start + 700]
        assert "Config.parseManifest(" in window, (
            "manifestReadProc must parse manifest.json with Config.parseManifest"
        )
        assert "parseHubConfig" not in window, (
            "manifestReadProc must not parse the manifest as a hub config"
        )
        assert "root.manifest =" in window, (
            "manifestReadProc must set root.manifest so the version binds to it"
        )

    def test_config_reader_uses_the_tested_parser(self):
        # The four-state parser is tested in test_config.py. If configReadProc
        # parses config.json inline instead, the tested code is dead and the
        # live path is untested duplicate logic (which is how the manifest
        # regression slipped through).
        text = read(REPO / "Panel.qml")
        start = text.index("id: configReadProc")
        window = text[start:start + 1200]
        assert "Config.parseHubConfig(" in window, (
            "configReadProc must map Config.parseHubConfig's result"
        )
        assert "JSON.parse(" not in window, (
            "configReadProc must not parse config.json inline"
        )


class TestHotReloadCoverage:
    """Every plugin file should be watched, or edits silently do nothing."""

    def test_all_plugin_files_are_watched(self):
        import re

        text = read(REPO / "Panel.qml")
        block = re.search(r"readonly property var watchedFiles: \[(.*?)\]", text, re.S)
        assert block, "no watchedFiles list in Panel.qml"
        watched = set(re.findall(r'"([^"]+)"', block.group(1)))

        present = set()
        for path in QML_FILES:
            present.add(relative(path))
        for path in (REPO / "model").glob("*.mjs"):
            present.add(relative(path))

        missing = sorted(present - watched)
        assert not missing, "not watched for hot reload:\n  " + "\n  ".join(missing)

    def test_watched_files_exist(self):
        import re

        text = read(REPO / "Panel.qml")
        block = re.search(r"readonly property var watchedFiles: \[(.*?)\]", text, re.S)
        watched = re.findall(r'"([^"]+)"', block.group(1))
        missing = [w for w in watched if not (REPO / w).exists()]
        assert not missing, "watchedFiles names missing files: " + ", ".join(missing)


class TestBackendReferences:
    """Cross-file references must resolve to something that exists.

    After the split, a tab calls `hub.someState` on the Panel root and
    `panel.someHelper()` on the HubPanel root. A renamed or removed member
    shows up as an undefined value at runtime, in whichever tab happens to be
    open, so both directions are checked statically here.
    """

    @staticmethod
    def _exposed(path):
        text = read(path)
        props = set(
            re.findall(r"^  (?:(?:required|readonly) +)*property [\w.]+ (\w+)", text, re.M)
        )
        funcs = set(re.findall(r"^  function (\w+)\(", text, re.M))
        sigs = set(re.findall(r"^  signal (\w+)", text, re.M))
        ids = set(re.findall(r"^\s*id: (\w+)", text, re.M))
        return props | funcs | sigs | ids

    def test_hub_members_resolve_on_panel(self):
        exposed = self._exposed(REPO / "Panel.qml")
        problems = []
        for path in QML_FILES:
            text = read(path)
            for match in re.finditer(r"\bhub\.(\w+)", text):
                name = match.group(1)
                # hub.docker.com is a URL in a tooltip, not a property.
                if text[match.end():match.end() + 4] == ".com":
                    continue
                if name not in exposed:
                    problems.append("%s: hub.%s" % (relative(path), name))
        assert not problems, "undefined backend members:\n  " + "\n  ".join(problems)

    def test_panel_members_resolve_on_hubpanel(self):
        exposed = self._exposed(REPO / "HubPanel.qml")
        problems = []
        for path in sorted((REPO / "ui").rglob("*.qml")):
            for name in re.findall(r"(?<![\w.])panel\.(\w+)", read(path)):
                if name not in exposed:
                    problems.append("%s: panel.%s" % (relative(path), name))
        assert not problems, "undefined panel members:\n  " + "\n  ".join(problems)


class TestRequiredProperties:
    """A `required property` with no value supplied is a load-time failure.

    Extracting a component turns everything it leaned on into a required
    property, and the compiler only complains when the panel is built. This
    checks every ui component's top-level required properties are supplied at
    its instantiation site.

    Delegate properties (modelData, index) are provided by the view, so only
    declarations at the component's own indentation are considered.
    """

    @staticmethod
    def _required(path):
        return re.findall(
            r"^  required property [\w.]+ (\w+)", read(path), re.M
        )

    @staticmethod
    def _instantiation(component, text):
        # Capture the component's block: from "Name {" to the matching brace.
        match = re.search(r"\b" + component + r"\s*\{", text)
        if not match:
            return None
        depth = 0
        for i in range(match.end() - 1, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[match.start():i + 1]
        return None

    def test_required_properties_are_supplied(self):
        # Components can be instantiated from HubPanel.qml or from a tab, so
        # every QML file that builds one is a candidate site.
        hosts = [read(REPO / "HubPanel.qml")] + [
            read(p) for p in sorted((REPO / "ui" / "tabs").glob("*.qml"))
        ]
        components = [
            p for p in list((REPO / "ui").glob("*.qml"))
            + list((REPO / "ui" / "tabs").glob("*.qml"))
        ]
        problems = []
        for path in components:
            name = path.stem
            required = self._required(path)
            if not required:
                continue
            block = None
            for text in hosts:
                block = self._instantiation(name, text)
                if block is not None:
                    break
            if block is None:
                problems.append("%s is never instantiated in any QML file" % name)
                continue
            for prop in required:
                if not re.search(r"\b" + prop + r"\s*:", block):
                    problems.append("%s requires %s but does not receive it" % (name, prop))
        assert not problems, "unsatisfied required properties:\n  " + "\n  ".join(problems)


class TestManifest:
    """The manifest is the contract Omarchy reads, and QML hardcodes its id.

    Panel.qml builds every plugin path from the literal
    `elena.vember-server-hub`, so changing the manifest id without changing
    those paths would leave the panel watching and reading a directory that no
    longer exists. These checks run anywhere, including CI, where Omarchy's own
    validator is unavailable.
    """

    REQUIRED = ("schemaVersion", "id", "name", "version", "build", "author", "license", "kinds", "entryPoints")

    @staticmethod
    def _manifest():
        import json

        return json.loads((REPO / "manifest.json").read_text())

    def test_required_fields_are_present(self):
        manifest = self._manifest()
        missing = [key for key in self.REQUIRED if key not in manifest]
        assert not missing, "manifest.json is missing: " + ", ".join(missing)

    def test_entry_points_exist(self):
        manifest = self._manifest()
        entry = manifest["entryPoints"]
        assert entry, "no entry points declared"
        for kind, path in entry.items():
            assert (REPO / path).is_file(), "%s entry point missing: %s" % (kind, path)

    def test_entry_point_kinds_are_declared(self):
        manifest = self._manifest()
        # "panel" and "barWidget" are how the shell finds the two entry points.
        for kind in manifest["entryPoints"]:
            assert kind in ("panel", "barWidget"), "unknown entry point kind: " + kind
        assert "panel" in manifest["entryPoints"]

    def test_id_matches_the_paths_hardcoded_in_qml(self):
        manifest = self._manifest()
        plugin_id = manifest["id"]
        offenders = []
        for path in QML_FILES:
            for match in re.finditer(r"plugins/([A-Za-z0-9._-]+)/", read(path)):
                if match.group(1) != plugin_id:
                    offenders.append("%s points at %s" % (relative(path), match.group(1)))
        assert not offenders, (
            "manifest id is %s but QML uses other plugin ids:\n  %s"
            % (plugin_id, "\n  ".join(sorted(set(offenders))))
        )

    def test_build_is_an_integer_and_version_is_semver(self):
        manifest = self._manifest()
        assert isinstance(manifest["build"], int), "build must be an integer"
        assert re.fullmatch(r"\d+\.\d+\.\d+", manifest["version"]), (
            "version must be MAJOR.MINOR.PATCH, got %s" % manifest["version"]
        )


class TestInstallWatchdog:
    """The install watchdog must end tracking even when the log has output.

    The original bug: a terminal closed midway leaves some output behind and a
    `tail -F` that never ends. The watchdog used to return early whenever the
    log was non-empty, so the panel sat on "running" forever. Liveness is the
    lock file's job, not the log's, so these checks pin that separation.
    """

    @staticmethod
    def _timer_block(name):
        # QML declares timers as `Timer { id: installStallTimer ... }`, so find
        # the id line and walk back to the opening brace of its block.
        text = read(REPO / "Panel.qml")
        id_match = re.search(r"^\s*id:\s*" + name + r"\s*$", text, re.M)
        assert id_match, "no `id: %s` in Panel.qml" % name
        open_idx = text.rfind("{", 0, id_match.start())
        assert open_idx >= 0, "no opening brace before `id: %s`" % name
        depth = 0
        for i in range(open_idx, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[open_idx:i + 1]
        raise AssertionError("unbalanced braces in %s" % name)

    def test_watchdog_repeats(self):
        block = self._timer_block("installStallTimer")
        assert re.search(r"\brepeat:\s*true", block), (
            "the watchdog must repeat; a one-shot timer cannot catch a terminal "
            "closed long after the install started"
        )

    def test_watchdog_does_not_bail_on_log_content(self):
        block = self._timer_block("installStallTimer")
        assert "installLog" not in block, (
            "the watchdog must not look at the log: a terminal closed after the "
            "first line would never be noticed. Check the lock pid instead."
        )

    def test_watchdog_checks_the_lock_pid(self):
        block = self._timer_block("installStallTimer")
        assert "lockCheckCommand" in block, (
            "liveness must be checked through InstallLog.lockCheckCommand, "
            "which runs `kill -0 <pid>` on the lock's pid"
        )

    def test_reattach_starts_the_watchdog(self):
        # The reattach branch must restart the watchdog, or an install the
        # panel re-attached to would never be watched for a closed terminal.
        text = read(REPO / "Panel.qml")
        reattach = text.index("Reattached to the running install")
        window = text[reattach:reattach + 900]
        assert "installStallTimer.restart()" in window, (
            "the reattach path must restart installStallTimer"
        )

    def test_omarchy_watchdog_exists_and_repeats(self):
        # The Omarchy update has the same failure mode as an install: close the
        # terminal mid-update and there is no exit marker. It needs the same
        # repeating liveness check, with the pid on line 1 of its lock.
        block = self._timer_block("omarchyUpdateStallTimer")
        assert re.search(r"\brepeat:\s*true", block), (
            "the Omarchy update watchdog must repeat"
        )
        assert "lockCheckCommand" in block and ", 1)" in block, (
            "the Omarchy update lock stores its pid on line 1"
        )
        assert "omarchyUpdateLog" not in block, (
            "the Omarchy watchdog must not bail on log content either"
        )

    def test_omarchy_reattach_starts_the_watchdog(self):
        text = read(REPO / "Panel.qml")
        reattach = text.index("Reattached to the running Omarchy update")
        window = text[reattach:reattach + 700]
        assert "omarchyUpdateStallTimer.restart()" in window, (
            "the Omarchy update reattach path must restart its watchdog"
        )

    def test_stop_install_refreshes_counts_like_finish(self):
        # finishInstall schedules a post-install refresh so counts update.
        # stopInstall is what the "dead" verdict calls when a terminal closes
        # mid-install; without the same refresh the panel keeps pre-install
        # counts forever. Both teardown paths must schedule the refresh.
        text = read(REPO / "Panel.qml")

        def body(fn):
            m = re.search(r"function " + fn + r"\([^)]*\)", text)
            assert m, "no %s() in Panel.qml" % fn
            start = text.index("{", m.end())
            depth = 0
            for i in range(start, len(text)):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        return text[start:i + 1]
            raise AssertionError("unbalanced braces in %s" % fn)

        for fn in ("finishInstall", "stopInstall"):
            b = body(fn)
            assert "installRefreshTimer.restart()" in b, (
                "%s must restart installRefreshTimer so counts refresh" % fn
            )
            assert "installRefreshTimer2.restart()" in b, (
                "%s must restart installRefreshTimer2 so slow installs catch up"
                % fn
            )


class TestPollSafety:
    """The 15s poll must not destroy state the user is looking at.

    `refreshAll()` runs on the poll timer while the panel is open. The old
    version reset the Dev tab's selected repository, its detail panel and the
    extra-apps list on every tick, so a repository being inspected was
    deselected every 15 seconds and a slow app scan was killed before it could
    finish. The poll now passes `preserveSelection`, and the scan is only
    started when none is in flight.
    """

    def test_poll_preserves_selection(self):
        text = read(REPO / "Panel.qml")
        # Find the poll timer's onTriggered and require it to preserve.
        id_match = re.search(r"^\s*id:\s*pollTimer\s*$", text, re.M)
        assert id_match, "no pollTimer in Panel.qml"
        window = text[id_match.start():id_match.start() + 400]
        assert "refreshAll(true)" in window, (
            "the poll timer must call refreshAll(true) so it preserves the "
            "user's selected repository"
        )

    def test_open_does_a_full_reset(self):
        text = read(REPO / "Panel.qml")
        # The open path keeps the full reset (no argument).
        open_match = re.search(r"function open\(payloadJson\)", text)
        assert open_match, "no open() in Panel.qml"
        window = text[open_match.start():open_match.start() + 500]
        assert "refreshAll()" in window and "refreshAll(true)" not in window, (
            "opening the panel should do a full refresh, not a preserving one"
        )

    def test_refresh_dev_honours_preserve(self):
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshDev\((\w+)\)", text)
        assert fn, "refreshDev must take a preserve flag"
        param = fn.group(1)
        body_start = text.index("{", fn.end())
        # walk to matching brace
        depth = 0
        for i in range(body_start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[body_start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in refreshDev")
        # The destructive resets must sit behind the keep guard.
        guard = body.index("if (!keep)")
        for prop in ("devSelectedRepoPath", "devRepoDetail", "devRepos = []"):
            idx = body.index(prop)
            assert idx > guard, (
                "%s must only be reset when not preserving the selection" % prop
            )

    def test_refresh_dev_does_not_restart_the_chain_mid_flight(self):
        # refreshDev runs on the 15s poll and drives the devTools -> devRepos ->
        # codeServer chain. Restarting devToolsProc unconditionally killed a
        # slow repo scan before it finished, leaving devRepos stale forever. The
        # poll path must start the chain only when none of it is in flight.
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshDev\((\w+)\)", text)
        assert fn, "refreshDev must take a preserve flag"
        body_start = text.index("{", fn.end())
        depth = 0
        for i in range(body_start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[body_start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in refreshDev")
        assert (
            "if (devToolsProc.running || devReposProc.running || codeServerProc.running)"
            in body
        ), (
            "the poll path of refreshDev must not restart the dev chain while "
            "any part of it is in flight"
        )

    def test_extra_apps_scan_is_not_restarted_mid_flight(self):
        text = read(REPO / "Panel.qml")
        idx = text.index("extraAppsScanProc.command = Gaming.scanCommand()")
        # The start must be guarded by a running check just above it.
        window = text[max(0, idx - 400):idx]
        assert "if (!extraAppsScanProc.running)" in window, (
            "the extra-apps scan must not be restarted while one is in flight, "
            "or a scan slower than the 15s poll never completes"
        )

    def test_refresh_games_honours_preserve(self):
        # The games tab has the same flicker as the Dev tab: counts blank to
        # "—" and the dedicated-server list empties if the poll resets them
        # every 15 seconds. The resets must sit behind the keep guard.
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshGames\((\w+)\)", text)
        assert fn, "refreshGames must take a preserve flag"
        body_start = text.index("{", fn.end())
        depth = 0
        for i in range(body_start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[body_start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in refreshGames")
        guard = body.index("if (!keep)")
        for prop in ("steamGameCount = -1", "steamDedicatedServers = []", "bnetGameCount = -1"):
            idx = body.index(prop)
            assert idx > guard, (
                "%s must only be reset when not preserving state" % prop
            )

    def test_tailscale_action_keeps_its_result_note(self):
        # tsActionProc.onExited writes a success/failure note and then refreshes
        # status. refreshTailscale() used to clear tailscaleNote unconditionally,
        # so the message was wiped in the same tick and the user never saw
        # whether the action worked. The handler must preserve it.
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshTailscale\((\w+)\)", text)
        assert fn, "refreshTailscale must take a preserve flag"
        body_start = text.index("{", fn.end())
        depth = 0
        for i in range(body_start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[body_start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in refreshTailscale")
        # The clear must sit behind the preserve guard.
        assert "preserveNote" in fn.group(1)
        guard = body.index("if (preserveNote !== true)")
        clear = body.index("tailscaleNote = \"\"")
        assert clear > guard, "tailscaleNote must only clear when not preserving"
        # And the action handler must pass the flag.
        action = text.index("id: tsActionProc")
        window = text[action:action + 900]
        assert "refreshTailscale(true)" in window, (
            "tsActionProc.onExited must preserve its result note"
        )


class TestDevToolsTargetedRefresh:
    """refreshDevTools() must be a targeted refresh, not a full repo rescan.

    It is called after installing a dev tool, where only the tool list and the
    code-server status can have changed. The old code declared a
    `devToolsOnlyRefresh` flag but never set it, so every install triggered a
    full repo scan; worse, the flag was cleared in devToolsProc before
    codeServerProc read it, so the "Dev tools refreshed." message could never
    fire. The flag is now set by refreshDevTools() and cleared once, at the end
    of the codeServerProc chain.
    """

    def test_refresh_dev_tools_sets_the_flag(self):
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshDevTools\(\)\s*\{", text)
        assert fn, "no refreshDevTools() in Panel.qml"
        window = text[fn.start():fn.start() + 400]
        assert "devToolsOnlyRefresh = true" in window, (
            "refreshDevTools must set devToolsOnlyRefresh so the repo scan is "
            "skipped after a tool install"
        )

    def test_tools_proc_does_not_clear_the_flag_early(self):
        # devToolsProc.onStreamFinished branches on the flag but must leave it
        # for codeServerProc.onExited to read and clear. (onExited clears it only
        # on the failure path, where codeServerProc never starts.)
        text = read(REPO / "Panel.qml")
        idx = text.index("id: devToolsProc")
        block_start = text.rindex("Process {", 0, idx)
        block_end = text.index("\n  Process {", idx)
        block = text[block_start:block_end]
        assert "devToolsOnlyRefresh" in block, "devToolsProc must branch on the flag"
        # Scope the check to onStreamFinished: that is where the flag must
        # survive. onExited's failure-path clear is legitimate.
        stream_start = block.index("onStreamFinished")
        stream_end = block.index("stderr:", stream_start)
        stream = block[stream_start:stream_end]
        assert "root.devToolsOnlyRefresh = false" not in stream, (
            "devToolsProc.onStreamFinished must not clear the flag; codeServerProc "
            "reads it to choose the status message and clears it at the end"
        )

    def test_code_server_proc_clears_the_flag(self):
        text = read(REPO / "Panel.qml")
        idx = text.index("id: codeServerProc")
        block_start = text.rindex("Process {", 0, idx)
        block_end = text.index("\n  Process {", idx)
        block = text[block_start:block_end]
        assert "root.devToolsOnlyRefresh = false" in block, (
            "codeServerProc.onExited must clear the flag; the poll's "
            "refreshDev(preserve=true) does not, so a leaked flag would make the "
            "next full refresh skip the repo scan"
        )

    def test_install_does_not_double_restart_code_server(self):
        # devInstallSilentProc.onExited used to call refreshDevTools() and then
        # restart codeServerProc by hand. refreshDevTools now chains into
        # codeServerProc itself, so the manual restart is a redundant race.
        text = read(REPO / "Panel.qml")
        idx = text.index("id: devInstallSilentProc")
        block_start = text.rindex("Process {", 0, idx)
        block_end = text.index("\n  Process {", idx)
        block = text[block_start:block_end]
        assert "refreshDevTools()" in block, "the install handler must refresh tools"
        assert "codeServerProc.running = true" not in block, (
            "the install handler must not restart codeServerProc by hand; "
            "refreshDevTools chains into it"
        )


class TestSteamScanPollSafety:
    """The Steam library scan must not be killed by the 15s poll.

    refreshGames() used to restart steamManifestProc unconditionally and force a
    steamVdfView reload on every tick. The VDF reload in turn restarted the
    manifest scan again, so a library scan on a large disk could be killed
    before it finished and the counts would never settle. The scan is now only
    started when none is in flight, and the VDF is only reloaded on a full
    refresh (the counts change on install, which does a full refresh).
    """

    def test_manifest_scan_guarded_against_restart(self):
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshGames\((\w+)\)", text)
        assert fn, "no refreshGames() in Panel.qml"
        body_start = text.index("{", fn.end())
        depth = 0
        for i in range(body_start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[body_start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in refreshGames")
        # The manifest start must sit behind a running guard.
        idx = body.index("steamManifestProc.command = Gaming.steamManifestCountCommandForDirs")
        window = body[max(0, idx - 200):idx]
        assert "if (!steamManifestProc.running)" in window, (
            "the Steam manifest scan must not be restarted while one is in "
            "flight, or a slow scan never finishes"
        )

    def test_vdf_reload_only_on_full_refresh(self):
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function refreshGames\((\w+)\)", text)
        body_start = text.index("{", fn.end())
        depth = 0
        for i in range(body_start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[body_start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in refreshGames")
        # The VDF path reset must sit inside its own `if (!keep)` guard, not
        # merely somewhere after the top reset block. Look in a tight window
        # before the reset for the guard.
        vdf = body.index("steamVdfView.path = \"\"")
        window = body[max(0, vdf - 250):vdf]
        assert "if (!keep) {" in window, (
            "steamVdfView must only be reloaded inside an `if (!keep)` guard, "
            "not on every poll (the reload restarts the manifest scan)"
        )


class TestDockerDetailPollSafety:
    """Selecting a container must not re-query its size on every poll.

    hub.dockerContainers is reassigned to fresh objects by the 15s poll, so the
    detail panel's `selected` object changes identity every tick. Keying the
    size query off `onSelectedChanged` therefore re-ran `docker ps -s` and
    blanked the size to "Querying…" every 15 seconds. It must key off the
    container *name*, which only changes when the user picks another container.
    """

    def test_size_query_keyed_off_name_not_object(self):
        text = read(REPO / "ui" / "tabs" / "ContainersTab.qml")
        assert "property string selectedName:" in text, (
            "the detail panel must expose a name-keyed selection property"
        )
        assert "onSelectedNameChanged:" in text, (
            "the size query must fire on name change, not object identity"
        )
        assert "onSelectedChanged:" not in text, (
            "onSelectedChanged fires every poll (dockerContainers is reassigned); "
            "use onSelectedNameChanged so the size query is not re-run each tick"
        )


class TestNoDeadProperties:
    """Every property Panel.qml declares must be read somewhere.

    Dead state is easy to leave behind and hard to notice: `sshHostKeys`,
    `tailscaleStatusText`, `gameMountSummary`, `dockerPullingImage`, `bnetNote`,
    `restartingForServerName` and `targetLineNo` were all assigned but never
    read. Two of them were fed by processes that ran real shell-outs on every
    15s poll, so the cost was not only clutter but wasted work every tick.

    This guard scans every QML file for a read of each declared property. A
    "read" is any occurrence of the bare name that is not the declaration and
    not a plain assignment (`name = ...`). It is intentionally lenient — a
    property used only as a JS object key or in a string still counts — because
    a false negative (missing a dead property) is cheaper than a false positive
    (failing on a live one).
    """

    QML_ALL = QML_FILES

    def _declared(self):
        text = read(REPO / "Panel.qml")
        names = re.findall(r"^\s*(?:readonly\s+)?property\s+\w+\s+(\w+)", text, re.M)
        return sorted(set(names))

    def _is_read_in(self, name, text):
        decl = re.compile(r"^\s*(?:readonly\s+)?property\s+\w+\s+" + re.escape(name) + r"\b")
        for m in re.finditer(r"\b" + re.escape(name) + r"\b", text):
            line_start = text.rfind("\n", 0, m.start()) + 1
            line_end = text.find("\n", m.end())
            line = text[line_start:line_end if line_end != -1 else len(text)]
            if decl.match(line):
                continue  # the declaration itself
            rest = text[m.end():m.end() + 4].lstrip()
            if rest.startswith("=") and not rest.startswith("=="):
                continue  # a plain assignment, not a read
            return True
        return False

    def test_no_property_is_assigned_but_never_read(self):
        texts = [(p, read(p)) for p in self.QML_ALL]
        dead = []
        for name in self._declared():
            if not any(self._is_read_in(name, t) for _, t in texts):
                dead.append(name)
        assert not dead, (
            "these properties are declared but never read (dead state): "
            + ", ".join(dead)
        )


class TestEditorLaunchFailure:
    """Opening authorized_keys must not claim success before it is known.

    sshAuthorizedKeysEditorProc used to set "Opened authorized_keys in editor."
    the moment the launch was requested, with no onExited handler. If
    omarchy-launch-editor was missing or failed, the user was told it opened
    when nothing happened. The status must be set from the process's exit code.
    """

    @staticmethod
    def _proc_block():
        text = read(REPO / "Panel.qml")
        id_match = re.search(r"^\s*id:\s*sshAuthorizedKeysEditorProc\s*$", text, re.M)
        assert id_match, "no sshAuthorizedKeysEditorProc in Panel.qml"
        open_idx = text.rfind("{", 0, id_match.start())
        depth = 0
        for i in range(open_idx, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[open_idx:i + 1]
        raise AssertionError("unbalanced braces in sshAuthorizedKeysEditorProc")

    def test_proc_has_on_exited(self):
        block = self._proc_block()
        assert "onExited:" in block, (
            "the editor proc must handle onExited so a failed launch is reported"
        )

    def test_success_status_set_on_exit_not_on_request(self):
        text = read(REPO / "Panel.qml")
        fn = re.search(r"function openAuthorizedKeysEditor\(\)", text)
        assert fn, "no openAuthorizedKeysEditor()"
        start = text.index("{", fn.end())
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[start:i + 1]
                    break
        else:
            raise AssertionError("unbalanced braces in openAuthorizedKeysEditor")
        assert "Opened authorized_keys in editor." not in body, (
            "openAuthorizedKeysEditor must not claim success before the process "
            "exits; set the success status from onExited instead"
        )


class TestContainerSelectionStability:
    """The container selection must survive a poll that reorders the list.

    hub.dockerContainers is reassigned every 15s and can be reordered — a
    container created at the top shifts every index down. An index-based
    selection (selectedContainerIndex) would then silently point at a different
    container, so the detail panel — including its Remove button — would target
    the wrong one. Selection must be keyed by the container *name*.
    """

    def test_selection_is_keyed_by_name(self):
        text = read(REPO / "ui" / "tabs" / "ContainersTab.qml")
        assert "selectedContainerIndex" not in text, (
            "index-based selection drifts when the poll reorders the list; key "
            "off the container name instead"
        )
        assert "selectedContainerName" in text, (
            "the tab must hold a name-keyed selection property"
        )

    def test_selected_is_looked_up_by_name(self):
        text = read(REPO / "ui" / "tabs" / "ContainersTab.qml")
        # The detail's `selected` must find the container by name in the list,
        # not index into it.
        m = re.search(r"property var selected:\s*\(function\(\)", text)
        assert m, "the detail `selected` must be looked up by name, not by index"
        window = text[m.start():m.start() + 400]
        assert ".name === want" in window or ".name === " in window, (
            "the lookup must compare container names"
        )


class TestLauncherFailureSurfacing:
    """Launchers must report a failed launch, not claim success forever.

    steamLaunchProc and bnetLaunchProc used to set "Launching …" and never
    inspect the exit code. omarchy-launch-battlenet exits 1 with a message when
    Battle.net is not installed, and a missing/failed binary is equally silent,
    so the user was left looking at "Launching Battle.net…" with nothing
    happening. Each launcher must have an onExited handler that surfaces a
    non-zero exit through Shell.failureMessage.
    """

    @staticmethod
    def _proc_block(name):
        text = read(REPO / "Panel.qml")
        id_match = re.search(r"^\s*id:\s*" + re.escape(name) + r"\s*$", text, re.M)
        assert id_match, "no " + name + " in Panel.qml"
        open_idx = text.rfind("{", 0, id_match.start())
        depth = 0
        for i in range(open_idx, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[open_idx:i + 1]
        raise AssertionError("unbalanced braces in " + name)

    def test_steam_launcher_checks_exit(self):
        block = self._proc_block("steamLaunchProc")
        assert "onExited:" in block, (
            "steamLaunchProc must handle onExited so a failed launch is reported"
        )
        assert "failureMessage" in block, (
            "a non-zero exit must surface through Shell.failureMessage"
        )

    def test_battlenet_launcher_checks_exit(self):
        block = self._proc_block("bnetLaunchProc")
        assert "onExited:" in block, (
            "bnetLaunchProc must handle onExited so a failed launch is reported"
        )
        assert "failureMessage" in block, (
            "a non-zero exit must surface through Shell.failureMessage"
        )


class TestSshKeySelectionStability:
    """SSH key removal must target the key the user selected, not its slot.

    hub.sshAuthorizedKeys is re-read every 15s and a key added above — or an
    external edit — shifts every index. An index-based selection would then
    point removeSelectedAuthorizedKey at a different key's lineNo and delete the
    wrong line from authorized_keys: data loss, not just a wrong detail panel.
    Selection must be keyed by the unique keyData blob, with the index derived.
    """

    def test_selection_is_keyed_by_keydata(self):
        text = read(REPO / "Panel.qml")
        assert 'property string sshSelectedKeyData' in text, (
            "the SSH key selection must hold the keyData identity"
        )
        # The index must be derived (readonly), not a writable slot.
        assert "readonly property int sshSelectedKeyIndex" in text, (
            "sshSelectedKeyIndex must be derived from sshSelectedKeyData so it "
            "cannot drift when the list is re-read"
        )

    def test_no_writable_index_assignment(self):
        text = read(REPO / "Panel.qml") + read(REPO / "ui" / "tabs" / "AccessTab.qml")
        # An assignment would be `sshSelectedKeyIndex =` not followed by `=`.
        assert not re.search(r"sshSelectedKeyIndex\s*=(?!=)", text), (
            "nothing may assign sshSelectedKeyIndex; set sshSelectedKeyData instead"
        )

    def test_derived_index_looks_up_keydata(self):
        text = read(REPO / "Panel.qml")
        m = re.search(r"readonly property int sshSelectedKeyIndex:\s*\{", text)
        assert m, "no derived sshSelectedKeyIndex"
        window = text[m.start():m.start() + 400]
        assert ".keyData === want" in window, (
            "the derived index must compare keyData to find the selected key"
        )


class TestConfigWriteFailureSurfacing:
    """A failed hub-config write must not look like a successful save.

    configWriteProc only handled a zero exit. On a non-zero exit with empty
    stderr the previous status message stayed up, so the user believed their
    settings were saved. A non-zero exit must surface through
    Shell.failureMessage (the stderr handler may already have set a specific
    message, so it must not be overwritten).
    """

    @staticmethod
    def _proc_block():
        text = read(REPO / "Panel.qml")
        id_match = re.search(r"^\s*id:\s*configWriteProc\s*$", text, re.M)
        assert id_match, "no configWriteProc in Panel.qml"
        open_idx = text.rfind("{", 0, id_match.start())
        depth = 0
        for i in range(open_idx, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[open_idx:i + 1]
        raise AssertionError("unbalanced braces in configWriteProc")

    def test_nonzero_exit_surfaces_failure(self):
        block = self._proc_block()
        assert "failureMessage" in block, (
            "a non-zero config-write exit must surface through Shell.failureMessage"
        )
        # The failure branch must exist inside onExited, not only the stderr handler.
        exit_idx = block.index("onExited:")
        exit_body = block[exit_idx:]
        assert "else" in exit_body, (
            "onExited must have an else branch for a non-zero exit"
        )


class TestSshAddKeyValidation:
    """A pasted key must be validated before addAuthorizedKey writes it.

    Without validation a private key, multi-line blob or typo is appended to
    authorized_keys and reported as added while never authenticating. The
    function must call Ssh.validatePublicKeyLine and bail on a bad result
    before starting the add process.
    """

    @staticmethod
    def _fn():
        text = read(REPO / "Panel.qml")
        m = re.search(r"function\s+addAuthorizedKey\s*\([^)]*\)\s*\{", text)
        assert m, "no addAuthorizedKey in Panel.qml"
        start = text.index("{", m.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced braces in addAuthorizedKey")

    def test_validates_before_writing(self):
        body = self._fn()
        assert "Ssh.validatePublicKeyLine" in body, (
            "addAuthorizedKey must validate the pasted key before writing it"
        )
        # The validation must gate the process start.
        val_idx = body.index("Ssh.validatePublicKeyLine")
        proc_idx = body.index("sshAuthorizedKeysAddProc.running = true")
        assert val_idx < proc_idx, (
            "validation must happen before the add process is started"
        )

    def test_rejects_on_invalid(self):
        body = self._fn()
        assert "v.ok" in body and "return" in body, (
            "addAuthorizedKey must return early when validation fails"
        )


class TestNoDeadModelExports:
    """Every exported model function must have a production caller.

    The model layer exports each class method twice: as a method on the
    instance and as a hoisted `export function` so QML can call
    `Module.name(...)`. That convenience makes it easy to leave a helper
    behind after its only caller is rewritten — and a test that exercises the
    helper then passes while nothing in the plugin calls it. Ten such exports
    had accumulated before this guard existed.

    A function is live if its name appears anywhere in production code
    (any .qml file or any .mjs file) outside its own definition and export
    wrapper. Tests do not count: a test is evidence about a function, not a
    caller of it.
    """

    def _production_text(self):
        files = [p for p in QML_FILES] + sorted((REPO / "model").glob("*.mjs"))
        return {p: read(p) for p in files}

    def test_every_export_has_a_caller(self):
        texts = self._production_text()
        dead = []
        for path in sorted((REPO / "model").glob("*.mjs")):
            source = texts[path]
            for match in re.finditer(r"^export function (\w+)\(", source, re.M):
                name = match.group(1)
                # Strip the wrapper itself and the class method definition, then
                # look for any remaining reference anywhere in production code.
                stripped = re.sub(
                    r"^export function " + name + r"\(\.\.\.args\).*$", "", source, flags=re.M
                )
                stripped = re.sub(
                    r"^\s*" + name + r"\([^)]*\)\s*\{", "", stripped, count=1, flags=re.M
                )
                referenced = bool(re.search(r"\b" + name + r"\b", stripped))
                if not referenced:
                    for other, text in texts.items():
                        if other == path:
                            continue
                        if re.search(r"\b" + name + r"\b", text):
                            referenced = True
                            break
                if not referenced:
                    dead.append(relative(path) + ":" + name)
        assert not dead, (
            "exported but never called in production code (delete it, or wire it "
            "up):\n  " + "\n  ".join(dead)
        )

    def test_the_guard_would_catch_a_dead_export(self):
        # Mutation check: plant a dead export in the model layer and confirm the
        # detection logic flags it. Done in memory so the tree is untouched.
        sample = "export class X {\n  orphan() {\n  return 1;\n  }\n}\n\nexport function orphan(...args) { return impl.orphan(...args); }\n"
        name = "orphan"
        stripped = re.sub(
            r"^export function " + name + r"\(\.\.\.args\).*$", "", sample, flags=re.M
        )
        stripped = re.sub(
            r"^\s*" + name + r"\([^)]*\)\s*\{", "", stripped, count=1, flags=re.M
        )
        assert not re.search(r"\b" + name + r"\b", stripped)


class TestExternalHandOffReachability:
    """The hub must get out of the way of anything it launches.

    The panel is a full-screen overlay with exclusive keyboard focus. Anything
    it starts lands behind it: not visible, and not clickable either, because
    the overlay's backdrop swallows the click. For an install terminal that
    means the sudo prompt and y/n questions the terminal exists for are
    unreachable, so the fix would be worthless; for an editor or a game
    launcher it means the click looks like it did nothing.

    Every action that hands off to a surface outside the hub therefore closes
    the hub. The hub's own background work — installs, scans, log streaming —
    is independent of panel visibility, so closing loses nothing, and
    reopening reattaches to whatever is running.
    """

    # Functions that start something the user must see or type into.
    HANDOFF_FUNCTIONS = [
        "runInstallInTerminal",
        "runOmarchyUpdateInPanel",
        "runTailscaleActionInTerminal",
        "openAuthorizedKeysEditor",
        "openCodeServer",
        "openBattlenetSetup",
        "launchSteam",
        "launchBattleNet",
        "launchExtraApp",
        "openRepoInEditor",
    ]

    def _panel(self):
        return read(REPO / "Panel.qml")

    def _fn(self, name):
        text = self._panel()
        match = re.search(r"function\s+" + name + r"\s*\([^)]*\)\s*\{", text)
        assert match, name + " not found in Panel.qml"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced braces in " + name)

    def test_the_helper_actually_closes_the_hub(self):
        # The rest of this class checks that the helper is *called*. If the
        # helper itself stopped closing, every one of those checks would still
        # pass while nothing closed.
        body = self._fn("handOffToExternalSurface")
        assert "requestClose()" in body, (
            "handOffToExternalSurface must call requestClose()"
        )

    @pytest.mark.parametrize("name", HANDOFF_FUNCTIONS)
    def test_launch_path_closes_the_hub(self, name):
        body = self._fn(name)
        assert "handOffToExternalSurface()" in body, (
            name + " must hand off to the external surface, or what it launches "
            "lands behind the hub overlay"
        )

    def test_update_terminal_has_the_install_app_id(self):
        # The focus selector is the class, so the update terminal needs the same
        # app-id as an install or the class selector can never match.
        body = self._fn("runOmarchyUpdateInPanel")
        assert "--app-id=vember-install" in body

    def test_focus_goes_through_the_hypr_helper(self):
        # A hand-rolled `hyprctl dispatch focuswindow ...` is the broken legacy
        # form on Hyprland 0.56. Focus must come from the model helper.
        text = self._panel()
        assert "Hypr.focusByClassScript" in text
        assert "hyprctl dispatch focuswindow" not in text

    def test_no_launch_path_closes_the_hub_by_hand(self):
        # Closing through the helper is what the guard above can see. A bare
        # requestClose() next to a launch would satisfy the user and hide from
        # the check, so the launch paths use the helper and nothing else.
        for name in self.HANDOFF_FUNCTIONS:
            body = self._fn(name)
            assert "requestClose()" not in body, (
                name + " should close the hub via handOffToExternalSurface()"
            )

    @pytest.mark.parametrize("name", ["openCodeServer", "openBattlenetSetup"])
    def test_browser_hand_off_checks_for_a_handler(self, name):
        # Qt.openUrlExternally returns false when no handler is configured.
        # Closing the hub regardless would leave the user with nothing open
        # and no message: the dead-button problem again.
        body = self._fn(name)
        check = body.find("if (!Qt.openUrlExternally(")
        assert check >= 0, name + " must check whether a browser opened"
        hand_off = body.find("handOffToExternalSurface()")
        assert hand_off > check, (
            name + " must only close the hub once the browser opened"
        )

    def test_install_and_update_never_run_together(self):
        # Both terminals use the `vember-install` window class, which is what
        # the focus step selects on. With two of them, focus lands on whichever
        # mapped first and the other one's prompts are missed.
        install = self._fn("runInstallInTerminal")
        update = self._fn("runOmarchyUpdateInPanel")
        assert "omarchyUpdateRunning" in install, (
            "runInstallInTerminal must refuse while an Omarchy update runs"
        )
        assert "installRunning" in update, (
            "runOmarchyUpdateInPanel must refuse while an install runs"
        )

    def test_reopening_mid_install_keeps_the_status_line(self):
        # The hub closes itself when an install starts, so reopening it while
        # the install runs is the normal path. refreshAll() clears the status
        # line for a fresh open; it must not do that mid-install, or the only
        # sign that anything is happening disappears.
        body = self._fn("refreshAll")
        clear = re.search(r"lastActionMessage = \"\";", body)
        assert clear, "refreshAll should still clear the status line"
        guard = body[: clear.start()]
        assert "installRunning" in guard, (
            "refreshAll must not clear the status line while an install runs"
        )
        assert "omarchyUpdateRunning" in guard, (
            "refreshAll must not clear the status line while an update runs"
        )


class TestLaunchFailureIsVisible:
    """A failed hand-off must reach the user, not just a closed panel.

    Every launch path closes the hub, so the status message a failed launch
    writes lands in a panel nobody is looking at. Without a notification, a
    launch that failed looks exactly like a button that does nothing.
    """

    PROCESSES = [
        "steamLaunchProc",
        "bnetLaunchProc",
        "extraAppLaunchProc",
        "devOpenRepoProc",
        "sshAuthorizedKeysEditorProc",
    ]

    def _panel(self):
        return read(REPO / "Panel.qml")

    def _process(self, name):
        text = self._panel()
        match = re.search(r"^\s*id:\s*" + name + r"\s*$", text, re.M)
        assert match, name + " not found in Panel.qml"
        start = text.rfind("Process {", 0, match.start())
        assert start >= 0, "no Process block for " + name
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced braces in " + name)

    @pytest.mark.parametrize("name", PROCESSES)
    def test_failure_notifies(self, name):
        body = self._process(name)
        assert "root.notify(" in body, (
            name + " must notify on failure; the hub is closed by then, so a "
            "status message alone is invisible"
        )

    def test_notify_uses_the_model_helper(self):
        text = self._panel()
        body = text[text.index("function notify(text)") :]
        body = body[: body.index("\n  }")]
        assert "Shell.notifyCommand" in body

    def test_notify_ignores_empty_text(self):
        text = self._panel()
        body = text[text.index("function notify(text)") :]
        body = body[: body.index("\n  }")]
        assert "length === 0" in body, "an empty message must not raise a notification"


class TestWatchdogFailuresAreVisible:
    """Watchdog verdicts are reported into a panel the hub has closed.

    The hub closes itself when an install or update starts, so "the terminal
    never opened", "the terminal closed early" and "no output yet, it may be
    asking for a password" all land in a panel nobody is looking at. Those are
    the moments the user most needs to know, so each one notifies.
    """

    # (kind, id, how many failure branches must notify). Counting matters:
    # an earlier version of this guard only asked whether the block contained
    # a notify call, so removing one of two still passed.
    BLOCKS = [
        ("Process", "installLockCheckProc", 2),
        ("Process", "omarchyUpdateLockCheckProc", 2),
        ("Timer", "installNoOutputTimer", 1),
    ]

    def _panel(self):
        return read(REPO / "Panel.qml")

    def _block(self, kind, name):
        text = self._panel()
        match = re.search(r"^\s*id:\s*" + name + r"\s*$", text, re.M)
        assert match, name + " not found in Panel.qml"
        start = text.rfind(kind + " {", 0, match.start())
        assert start >= 0, "no " + kind + " block for " + name
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced braces in " + name)

    @pytest.mark.parametrize("kind,name,expected", BLOCKS)
    def test_every_failure_branch_notifies(self, kind, name, expected):
        body = self._block(kind, name)
        found = body.count("root.notify(")
        assert found == expected, (
            name + " has " + str(found) + " notify call(s), expected " + str(expected) +
            "; each message that lands in the closed panel must notify"
        )

    def test_launcher_exit_does_not_stop_tracking(self):
        # The launcher process finishes as soon as the detached terminal is
        # spawned, and its exit status is the focus snippet's. Treating a
        # non-zero exit as "the terminal never opened" killed tracking of a
        # real install; the watchdog owns that verdict.
        body = self._block("Process", "installTerminalProc")
        assert "finishInstall" not in body, (
            "installTerminalProc must not stop tracking; the watchdog decides"
        )
        assert "stopInstall" not in body
