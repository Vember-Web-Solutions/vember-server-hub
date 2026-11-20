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


def _refresh_games_body(text):
    """Return the source of refreshGames(), balanced braces and all."""
    fn = re.search(r"function refreshGames\((\w+)\)", text)
    assert fn, "no refreshGames() in Panel.qml"
    start = text.index("{", fn.end())
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    raise AssertionError("unbalanced braces in refreshGames")


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


class TestNoSelfRestartingFileWatcher:
    """The plugin must never restart the shell because its own files changed.

    It used to watch all of its source files and, on any change, run
    `omarchy restart shell` and reopen the hub. That restarted the whole desktop
    shell on every save, popped a full-screen overlay that took exclusive
    keyboard focus, and left a fresh quickshell runtime directory behind — 542 of
    them filled the 1.3 GB /run/user/1000 tmpfs, after which shell restarts
    failed and shells multiplied (24 at one point, 7.6 GB of RAM).

    Omarchy already reloads a plugin in place when a file is saved (an
    inotifywait watcher on close_write), so the restart added nothing.

    The Reload button and the post-update reload stay — those are the user
    asking. This pins that no automatic path reaches them.
    """

    def test_the_plugin_does_not_watch_its_own_files(self):
        offenders = []
        for path in QML_FILES:
            text = read(path)
            for token in ("watchChanges", "scheduleHotReload", "watchedFiles"):
                if token in text:
                    offenders.append(relative(path) + ": " + token)
        assert not offenders, (
            "the plugin must not watch its own files; a save would restart the "
            "shell:\n  " + "\n  ".join(offenders)
        )

    def test_hot_reload_is_only_started_by_the_user(self):
        text = read(REPO / "Panel.qml")
        assert text.count("hotReloadProc.running = true") == 1, (
            "hotReloadProc must be started in exactly one place"
        )
        # No timer may reach it: that would make the restart automatic.
        assert "onTriggered: root.hotReloadHub()" not in text, (
            "a timer must not trigger hotReloadHub()"
        )

    def test_the_manual_reload_is_still_reachable(self):
        callers = set()
        for path in QML_FILES:
            body = read(path)
            # Skip the definition itself.
            body = body.replace("function hotReloadHub()", "")
            if "hotReloadHub()" in body:
                callers.add(relative(path))
        assert callers == {"HubPanel.qml", "ui/UpdateDialog.qml"}, (
            "hotReloadHub() should be called only by the Reload button and the "
            "post-update path; found: %s" % sorted(callers)
        )


class TestPanelReopenGoesThroughShell:
    """Reopening the panel must go through the shell's own state.

    requestClose() closes through shell.hide(), which drops the plugin from the
    shell's openPanelIds. Reopening with root.open() puts the layer back on
    screen while the shell still believes the panel is closed, so isPluginOpen(),
    toggle() and the next hide() disagree with what the user sees. It only looks
    harmless because keepLoaded keeps the Loader mounted, and that is a property
    of the manifest rather than of this code path.
    """

    @staticmethod
    def _without_comments(text):
        # Good enough for a scan: drop everything from a // to end of line. A
        # URL in a string would be truncated too, which only ever hides a match
        # we are not looking for.
        return "\n".join(line.split("//", 1)[0] for line in text.splitlines())

    def test_root_open_is_only_the_shell_less_fallback(self):
        text = self._without_comments(read(REPO / "Panel.qml"))
        calls = list(re.finditer(r"root\.open\s*\(", text))
        assert len(calls) <= 1, (
            "root.open() should exist only as the fallback for when the shell is "
            "unavailable; found %d calls" % len(calls)
        )
        for m in calls:
            window = text[max(0, m.start() - 400):m.start()]
            assert "shell.summon(pluginId" in window, (
                "root.open() may only follow a failed shell.summon(): reopening "
                "directly leaves the shell believing the panel is closed"
            )

    def test_reopen_timer_uses_summon(self):
        text = read(REPO / "Panel.qml")
        block = re.search(r"id:\s*serverNameReopenTimer(.*?)\n  \}", text, re.S)
        assert block, "serverNameReopenTimer not found in Panel.qml"
        assert "shell.summon(pluginId" in block.group(1), (
            "serverNameReopenTimer must reopen through shell.summon(pluginId, ...)"
        )


class TestPrismInstanceCountIsWired:
    """The Prism count must reach the library summary, not sit as dead state."""

    def test_panel_defines_and_resets_the_count(self):
        text = read(REPO / "Panel.qml")
        assert "property int prismInstanceCount: -1" in text
        assert "prismInstanceCount = -1;" in text, (
            "a full refresh must clear the old count before rescanning"
        )

    def test_panel_starts_the_scan_with_a_poll_guard(self):
        text = read(REPO / "Panel.qml")
        assert "restartGamingProc(prismInstanceCountProc, Gaming.prismInstanceCountCommand(homeDir), keep);" in text, (
            "the scan must go through the helper: full refresh restarts it, "
            "the 15s poll keeps the running guard so a slow find can finish"
        )

    def test_the_process_writes_the_property(self):
        text = read(REPO / "Panel.qml")
        block = re.search(
            r"id:\s*prismInstanceCountProc(.*?)\n  \}", text, re.S
        )
        assert block, "prismInstanceCountProc not found in Panel.qml"
        assert "root.prismInstanceCount = Gaming.parsePrismInstanceCount(text)" in block.group(1)

    def test_summary_includes_it_in_total_and_known_counts(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert "property int prismCount: hub.prismInstanceCount >= 0 ? hub.prismInstanceCount : 0" in text
        assert "property int totalKnownGames: steamCount + bnetCount + prismCount" in text
        assert "hub.prismInstanceCount >= 0" in text, (
            "the summary must treat a measured zero as known, and -1 as unknown"
        )


class TestMinecraftVersionCountIsWired:
    """The vanilla Minecraft count must reach the library summary."""

    def test_panel_defines_and_resets_the_count(self):
        text = read(REPO / "Panel.qml")
        assert "property int minecraftVersionCount: -1" in text
        assert "minecraftVersionCount = -1;" in text, (
            "a full refresh must clear the old count before rescanning"
        )

    def test_panel_starts_the_scan_with_a_poll_guard(self):
        text = read(REPO / "Panel.qml")
        assert "restartGamingProc(minecraftVersionCountProc, Gaming.minecraftVersionCountCommand(homeDir), keep);" in text, (
            "the scan must go through the helper: full refresh restarts it, "
            "the 15s poll keeps the running guard so a slow find can finish"
        )

    def test_the_process_writes_the_property(self):
        text = read(REPO / "Panel.qml")
        block = re.search(
            r"id:\s*minecraftVersionCountProc(.*?)\n  \}", text, re.S
        )
        assert block, "minecraftVersionCountProc not found in Panel.qml"
        assert "root.minecraftVersionCount = Gaming.parseMinecraftVersionCount(text)" in block.group(1)

    def test_summary_includes_it_in_total_and_known_counts(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert "property int minecraftCount: hub.minecraftVersionCount >= 0 ? hub.minecraftVersionCount : 0" in text
        assert "property int totalKnownGames: steamCount + bnetCount + prismCount + minecraftCount" in text
        assert "hub.minecraftVersionCount >= 0" in text, (
            "the summary must treat a measured zero as known, and -1 as unknown"
        )


class TestGameLogIsCollapsible:
    """Both live-log panels share one collapse toggle in the Games tab."""

    def test_shared_state_and_toggle_exist(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert "property bool gameLogExpanded:" in text
        assert text.count("onClicked: gameLogExpanded = !gameLogExpanded") == 2, (
            "both the Launchers and Apps log panels need the toggle"
        )

    def test_both_log_bodies_follow_the_state(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert text.count("visible: gameLogExpanded") == 2, (
            "both log bodies must collapse; a half-wired toggle leaves one open"
        )


class TestHeroicGameCountIsWired:
    """The Heroic count must reach the library total."""

    def test_panel_defines_and_resets_the_count(self):
        text = read(REPO / "Panel.qml")
        assert "property int heroicGameCount: -1" in text
        assert "heroicGameCount = -1;" in text

    def test_panel_starts_the_scan_with_a_poll_guard(self):
        text = read(REPO / "Panel.qml")
        assert "restartGamingProc(heroicGameCountProc, Gaming.heroicGameCountCommand(homeDir), keep);" in text

    def test_the_process_writes_the_property(self):
        text = read(REPO / "Panel.qml")
        block = re.search(r"id:\s*heroicGameCountProc(.*?)\n  \}", text, re.S)
        assert block, "heroicGameCountProc not found in Panel.qml"
        assert "root.heroicGameCount = Gaming.parseHeroicGameCount(text)" in block.group(1)

    def test_summary_includes_it_in_total_and_known_counts(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert "property int heroicCount: hub.heroicGameCount >= 0 ? hub.heroicGameCount : 0" in text
        assert "property int totalKnownGames: steamCount + bnetCount + prismCount + minecraftCount + heroicCount" in text
        assert "hub.heroicGameCount >= 0" in text


class TestGameLibraryIsStackedBar:
    """The library summary reads as one left-to-right stacked bar."""

    def _block(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        # The stacked bar is the clipped rounded track holding a Row of segments.
        start = text.index("// Single stacked composition bar")
        end = text.index("Column {\n          visible: libraryCol.hasAnyInstalled", start)
        return text[start:end]

    def test_bar_is_hidden_until_a_count_is_known(self):
        block = self._block()
        assert "visible: libraryCol.hasKnownCounts && libraryCol.totalKnownGames > 0" in block

    def test_one_segment_per_source_with_proportional_width(self):
        block = self._block()
        for count in ("steamCount", "bnetCount", "prismCount", "minecraftCount", "heroicCount"):
            assert "libraryCol." + count + " / libraryCol.totalKnownGames" in block, (
                count + " is missing from the stacked bar"
            )
        assert block.count("Behavior on width") == 5, (
            "each of the five segments should animate its width"
        )

    def test_segments_are_laid_out_left_to_right(self):
        block = self._block()
        colors = ["#66c0f4", "#00aeff", "#7ac74f", "#e0a53c", "#e43357"]
        positions = [block.index(c) for c in colors]
        assert positions == sorted(positions), "segments must keep source order left to right"
        assert "Row {" in block and "anchors.fill: parent" in block


class TestLogsStartCollapsed:
    """Both live logs default to collapsed but remain expandable."""

    def test_gaming_log_starts_collapsed_with_toggle(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert "property bool gameLogExpanded: false" in text
        assert "onClicked: gameLogExpanded = !gameLogExpanded" in text

    def test_omarchy_update_log_starts_collapsed_with_toggle(self):
        text = read(REPO / "ui/tabs/OverviewTab.qml")
        assert "property bool omarchyLogExpanded: false" in text
        assert "onClicked: omarchyLogExpanded = !omarchyLogExpanded" in text
        assert "visible: omarchyLogExpanded" in text, (
            "the update log body must be gated by the collapse state"
        )


class TestMinecraftServerIsWired:
    """Gaming → Servers can create a server and inspect an existing one."""

    def test_panel_has_create_state_and_processes(self):
        text = read(REPO / "Panel.qml")
        assert "property bool mcServerCreateBusy: false" in text
        assert "property string mcServerLogsText: \"\"" in text
        assert "id: mcServerCreateProc" in text
        assert "Docker.createMinecraftServerCommand(opts)" in text
        assert "id: mcServerLogsProc" in text
        assert "Docker.logsCommand(mcServerLogsName, 200)" in text
        assert "id: mcDataDirProc" in text
        assert "Docker.inspectDataDirCommand(mcDataDirName)" in text

    def test_create_failure_notifies_and_refreshes(self):
        text = read(REPO / "Panel.qml")
        block = re.search(r"id:\s*mcServerCreateProc(.*?)\n  \}", text, re.S)
        assert block, "mcServerCreateProc not found"
        assert "root.notifyIfClosed(root.lastActionMessage)" in block.group(1)
        assert "root.refreshDocker()" in block.group(1)
        assert "root.refreshGames()" in block.group(1)
        assert "if (cancelled)" in block.group(1), (
            "a user-cancelled pull must not be reported as a failure"
        )

    def test_cancel_is_wired_to_the_process(self):
        text = read(REPO / "Panel.qml")
        assert "function cancelMinecraftServerCreate()" in text
        assert "mcServerCreateProc.cancelled = true;" in text
        assert "mcServerCreateProc.running = false;" in text

    def test_servers_tab_opens_the_guided_wizard(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert "hub.openMinecraftServerWizard()" in text
        assert "hub.cancelMinecraftServerCreate()" in text
        assert "New Minecraft server" in text
        assert "Start the server wizard" in text

    def test_wizard_has_four_steps_and_themed_dropdowns(self):
        wizard = read(REPO / "ui/MinecraftServerWizard.qml")
        for step in ("Client", "Runtime", "Options", "Review"):
            assert '"' + step + '"' in wizard, step + " is missing from the step rail"
        for option in ("Wizard.serverTypeOptions()", "Wizard.versionOptions()",
                       "Wizard.memoryOptions(Wizard.isModdedType(panel.hub.mcServerTypeDraft))",
                       "Wizard.difficultyOptions()", "hub.mcWizardSetType(value)"):
            assert option in wizard, option + " has no dropdown"
        assert "hub.mcWizardCreate()" in wizard
        assert "hub.mcWizardPullImage()" in wizard
        assert "hub.mcWizardInstallClient()" in wizard
        assert "import \"../model/MinecraftWizard.mjs\" as Wizard" in wizard

    def test_existing_servers_get_all_controls(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        for call in (
            'hub.runDockerAction("start", modelData.name)',
            'hub.runDockerAction("stop", modelData.name)',
            'hub.runDockerAction("restart", modelData.name)',
            "hub.showMinecraftServerLogs(modelData.name)",
            "hub.openMinecraftDataFolder(modelData.name)",
        ):
            assert call in text, call + " is not wired to a server row"
        assert "hub.clearMinecraftServerLogs()" in text
        assert "hub.mcServerLogsText" in text, "the log viewer has no content"


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

    def test_panel_is_keep_loaded(self):
        # Without keepLoaded the shell's Loader deactivates the panel when
        # shell.hide() removes it from openPanelIds, destroying every Process
        # and Timer in it. The install/update watchdogs and the notification
        # queue live there, so a failure that lands after handOffToExternalSurface
        # closes the hub (a failed launch, a watchdog verdict) would never
        # notify. The panel is invisible while closed because HubPanel.qml binds
        # `visible: hub.opened` and drops keyboard focus, so keeping it loaded
        # does not leave it on screen.
        manifest = self._manifest()
        assert manifest.get("keepLoaded") is True, (
            "manifest.json must set \"keepLoaded\": true or the panel unloads "
            "when the hub closes and its watchdogs and notifications die with it"
        )
        hub_panel = read(REPO / "HubPanel.qml")
        assert re.search(r"visible:\s*hub\.opened", hub_panel), (
            "HubPanel must gate visibility on hub.opened so a keepLoaded panel "
            "stays hidden while closed"
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

    def test_post_install_refresh_skips_a_new_install(self):
        # refreshAfterInstall runs 2.5s and 9s after an install finishes. If a
        # new install started in that window, a full games reset would blank
        # the counts while it streams; the new install refreshes on its own
        # finish instead.
        text = read(REPO / "Panel.qml")
        match = re.search(r"function refreshAfterInstall\(\)\s*\{", text)
        assert match, "no refreshAfterInstall()"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[start : i + 1]
                    break
        else:
            raise AssertionError("unbalanced refreshAfterInstall")
        guard = body.find("if (installRunning)")
        assert guard >= 0, "refreshAfterInstall must skip while an install runs"
        assert body.find("refreshGames()") > guard, (
            "the installRunning guard must come before the games reset"
        )

    def test_dev_refresh_survives_an_overlapping_install(self):
        # The post-install refresh must not re-derive "was this a dev install"
        # from installRunningId: a second install started inside the 2.5s/9s
        # window replaces that id, so a dev install followed quickly by an app
        # install would never rescan the tools. A pending flag set at finish
        # time and consumed by the refresh is the fix.
        text = read(REPO / "Panel.qml")
        assert re.search(
            r"property bool devRefreshPending\s*:\s*false", text
        ), "Panel.qml must declare devRefreshPending"

        refresh = self._function_body(text, "refreshAfterInstall")
        assert "installIsDev" not in refresh, (
            "refreshAfterInstall must not gate the dev refresh on installIsDev"
        )
        flag = refresh.find("devRefreshPending")
        scan = refresh.find("refreshDevTools()")
        assert flag >= 0, "refreshAfterInstall must consume devRefreshPending"
        assert scan > flag, "devRefreshPending must be checked before refreshDevTools()"
        assert "devRefreshPending = false" in refresh, (
            "the pending flag must be consumed, not left set forever"
        )

        for fn_name in ("finishInstall", "stopInstall"):
            body = self._function_body(text, fn_name)
            assert "if (installIsDev)" in body, fn_name + " must branch on installIsDev"
            set_at = body.find("devRefreshPending = true")
            assert set_at >= 0, fn_name + " must set devRefreshPending"
            assert set_at > body.find("if (installIsDev)"), (
                fn_name + " must set the flag inside the installIsDev branch"
            )

    @staticmethod
    def _function_body(text, name):
        match = re.search(r"function " + name + r"\([^)]*\)\s*\{", text)
        assert match, "no " + name + "()"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced " + name)

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


class TestNoLoginTimeWork:
    """A keepLoaded panel exists at login, so nothing may start on its own.

    The manifest sets "keepLoaded": true, so the panel is instantiated when the
    shell starts rather than on first open. That makes every unconditional
    timer and Process in Panel.qml a login-time cost -- and the plugin update
    check runs a git fetch against GitHub. Before keepLoaded the panel was only
    built on open, so the startup check naturally ran 4s after the first open.
    These checks keep the login quiet.
    """

    def test_startup_update_check_waits_for_the_hub_to_open(self):
        text = read(REPO / "Panel.qml")
        match = re.search(r"id:\s*pluginUpdateStartupCheckTimer", text)
        assert match, "no pluginUpdateStartupCheckTimer"
        window = text[match.start():match.start() + 600]
        assert "running: root.opened" in window, (
            "the startup update check must be gated on root.opened; with "
            "keepLoaded it would otherwise git fetch on every login"
        )
        assert "running: true" not in window, (
            "the startup update check must not run unconditionally"
        )

    def test_no_unconditional_timer_in_the_panel(self):
        # A Timer with `running: true` in Panel.qml would fire at login, because
        # the panel is keepLoaded. Per-delegate timers elsewhere (ToastStack)
        # are scoped to a delegate that only exists while a toast is shown, so
        # they are not covered by this check.
        text = read(REPO / "Panel.qml")
        offenders = []
        for match in re.finditer(r"Timer\s*\{", text):
            # Take the block up to the matching close brace.
            start = match.end() - 1
            depth = 0
            for i in range(start, len(text)):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        block = text[start:i + 1]
                        break
            else:
                continue
            if re.search(r"^\s*running:\s*true\s*$", block, re.M):
                id_match = re.search(r"id:\s*(\w+)", block)
                offenders.append(id_match.group(1) if id_match else "<anonymous>")
        assert not offenders, (
            "these Timers run unconditionally, so they fire at login now that "
            "the panel is keepLoaded: " + ", ".join(offenders)
        )


class TestTransientStateIsClearedOnClose:
    """A keepLoaded panel survives a close, so its transient state must reset.

    Before keepLoaded, closing the hub destroyed the panel and every property
    with it. Now the panel is unloaded-but-alive, so a dialog left open or a
    password typed and abandoned would persist across a close/open cycle. The
    password is the one that matters: it is only cleared after a successful
    submit, so without this reset it would sit in memory for the rest of the
    session and be redisplayed on the next open.
    """

    RESET = (
        "confirmPrune",
        "confirmRemoveSshKey",
        "confirmRemoveCodeServer",
        "confirmRemoveGameServer",
        "codeServerSetupPassword",
        "settingsMenuOpen",
        "arrangeTabsOpen",
    )

    def test_reset_runs_when_the_panel_hides(self):
        text = read(REPO / "HubPanel.qml")
        assert re.search(r"onVisibleChanged:\s*if \(!visible\) resetTransientState\(\)", text), (
            "HubPanel must reset transient state when it hides; the panel is "
            "keepLoaded, so state otherwise survives a close"
        )

    @pytest.mark.parametrize("prop", RESET)
    def test_reset_clears_each_transient_property(self, prop):
        text = read(REPO / "HubPanel.qml")
        match = re.search(r"function resetTransientState\(\)\s*\{", text)
        assert match, "no resetTransientState() in HubPanel.qml"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[start : i + 1]
                    break
        else:
            raise AssertionError("unbalanced resetTransientState")
        assert re.search(r"panel\." + prop + r"\s*=", body), (
            "resetTransientState must clear panel.%s" % prop
        )


class TestCodeServerSetupHasAnEscapeHatch:
    """A hung setup must not lock the Code Server UI until a shell restart.

    The setup chain has no timeout, and start, stop, uninstall and set-up-again
    are all disabled while codeServerBusy. A stall timer that fired during a
    legitimately slow pull would be a false failure, so the escape hatch is a
    user-driven cancel instead. It must stop every process in the chain, not
    just the last one, or a stopped pull would still be running.
    """

    CHAIN = (
        "codeServerSetupPrepProc",
        "codeServerSetupPullProc",
        "codeServerSetupRunProc",
        "codeServerSetupProvisionProc",
        "codeServerActionProc",
        "codeServerSetupPollTimer",
    )

    def _body(self):
        text = read(REPO / "Panel.qml")
        match = re.search(r"function cancelCodeServerSetup\(\)\s*\{", text)
        assert match, "no cancelCodeServerSetup() in Panel.qml"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced cancelCodeServerSetup")

    @pytest.mark.parametrize("proc", CHAIN)
    def test_cancel_stops_each_process_in_the_chain(self, proc):
        body = self._body()
        assert proc in body, (
            "cancelCodeServerSetup must stop %s; leaving one running means the "
            "cancel only looks like it worked" % proc
        )

    def test_cancel_clears_the_busy_flag(self):
        assert re.search(r"codeServerBusy\s*=\s*false", self._body()), (
            "cancelCodeServerSetup must clear codeServerBusy or the buttons stay "
            "disabled"
        )

    def test_the_cancel_is_reachable_from_the_ui(self):
        text = read(REPO / "ui" / "tabs" / "DevTab.qml")
        assert "hub.cancelCodeServerSetup()" in text, (
            "the Dev tab must offer the cancel, or it is unreachable"
        )
        # And it must be visible precisely while busy, which is when it is needed.
        at = text.index("hub.cancelCodeServerSetup()")
        window = text[max(0, at - 600):at]
        assert "visible: hub.codeServerBusy" in window, (
            "the cancel button must be visible while codeServerBusy"
        )


class TestDockerPullHasAnEscapeHatch:
    """A stalled image pull must not disable the container forever.

    `docker pull` has no timeout and every action on the container is disabled
    while it runs. A dropped network or a hung registry leaves dockerPullActive
    true indefinitely. Stopping is safe — Docker keeps the layers it already
    fetched — so the escape hatch is user-driven, like the Code Server one.

    The subtle part: stopping the process makes onExited fire with a signal
    code, and the failure branch would then report "Pull failed (code 143)"
    over the message the user caused. The cancelled flag must be set before the
    process is stopped, and checked before the failure message.
    """

    def _cancel_body(self):
        text = read(REPO / "Panel.qml")
        match = re.search(r"function cancelDockerPull\(\)\s*\{", text)
        assert match, "no cancelDockerPull() in Panel.qml"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start : i + 1]
        raise AssertionError("unbalanced cancelDockerPull")

    def _pull_block(self):
        text = read(REPO / "Panel.qml")
        start = text.index("id: dockerPullProc")
        return text[start : text.index("Process {", start)]

    def test_cancel_stops_the_pull_and_clears_busy(self):
        body = self._cancel_body()
        assert "dockerPullProc.running = false" in body, (
            "cancelDockerPull must stop the pull process"
        )
        assert re.search(r"dockerPullActive\s*=\s*false", body), (
            "cancelDockerPull must clear dockerPullActive"
        )
        assert re.search(r"dockerBusy\s*=\s*false", body), (
            "cancelDockerPull must clear dockerBusy or the actions stay disabled"
        )

    def test_the_cancel_flag_is_set_before_stopping(self):
        body = self._cancel_body()
        flag = body.find("dockerPullProc.cancelled = true")
        stop = body.find("dockerPullProc.running = false")
        assert flag != -1, "cancelDockerPull must set the cancelled flag"
        assert stop != -1
        assert flag < stop, (
            "the cancelled flag must be set before the process is stopped, or "
            "onExited can run first and report a failure the user did not cause"
        )

    def test_the_exit_handler_does_not_report_a_cancel_as_a_failure(self):
        block = self._pull_block()
        guard = block.find("if (cancelled)")
        failure = block.find("Pull failed")
        assert guard != -1, (
            "dockerPullProc.onExited must check the cancelled flag"
        )
        assert failure != -1, "the failure branch is missing entirely"
        assert guard < failure, (
            "the cancelled guard must come before the failure message, or a "
            "stopped pull is reported as a failure"
        )
        window = block[guard:failure]
        assert "return" in window, (
            "the cancelled branch must return before the failure handling"
        )

    def test_the_cancel_is_reachable_from_the_ui(self):
        text = read(REPO / "ui" / "tabs" / "ContainersTab.qml")
        assert "hub.cancelDockerPull()" in text, (
            "the Containers tab must offer the cancel, or it is unreachable"
        )
        at = text.index("hub.cancelDockerPull()")
        window = text[max(0, at - 500):at]
        assert "visible: containerDetails.selPulling" in window, (
            "the cancel button must be visible while that container is pulling"
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
    before it finished and the counts would never settle. The 15s poll now goes
    through restartGamingProc(..., keep=true), which keeps the running guard;
    a full refresh (open/install) intentionally forces a fresh scan, and the
    VDF is only reloaded there (the counts change on install).
    """

    def test_manifest_scan_guarded_against_restart_on_poll(self):
        text = read(REPO / "Panel.qml")
        body = _refresh_games_body(text)
        assert "restartGamingProc(steamManifestProc," in body, (
            "the Steam manifest scan must be started through the helper, which "
            "keeps the running guard on the 15s poll"
        )
        helper = re.search(
            r"function restartGamingProc\(proc, command, keep\) \{(.*?)\n  \}",
            text, re.S
        )
        assert helper, "restartGamingProc helper is missing"
        assert "if (!proc.running) proc.running = true;" in helper.group(1), (
            "the helper must keep the running guard so a slow scan is not "
            "killed by the 15s poll"
        )

    def test_vdf_reload_only_on_full_refresh(self):
        text = read(REPO / "Panel.qml")
        body = _refresh_games_body(text)
        # The VDF path reset must sit inside its own `if (!keep)` guard, not
        # merely somewhere after the top reset block. Look in a tight window
        # before the reset for the guard.
        vdf = body.index("steamVdfView.path = \"\"")
        window = body[max(0, vdf - 250):vdf]
        assert "if (!keep) {" in window, (
            "steamVdfView must only be reloaded inside an `if (!keep)` guard, "
            "not on every poll (the reload restarts the manifest scan)"
        )


class TestGamingCountsRecoverOnFullRefresh:
    """A dash must never be the last word on a game count.

    On a full refresh (open, install, config save) refreshGames resets every
    count to -1. A Process still flagged `running` from an earlier session
    would never deliver into those reset counters, so the row stayed at "—"
    until the user hit Reload — which recreates the process objects. A plain
    open must now do what Reload did: force a fresh scan. The 15s poll keeps
    its guard, and additionally re-requests a count that has exited without
    producing a value.
    """

    COUNT_PROCS = (
        "steamManifestProc", "bnetGameCountProc", "prismInstanceCountProc",
        "minecraftVersionCountProc", "heroicGameCountProc",
    )

    def _helper(self, text):
        match = re.search(
            r"function restartGamingProc\(proc, command, keep\) \{(.*?)\n  \}",
            text, re.S
        )
        assert match, "restartGamingProc helper is missing"
        return match.group(1)

    def test_full_refresh_force_restarts(self):
        text = read(REPO / "Panel.qml")
        helper = self._helper(text)
        assert "if (!keep) proc.running = false;" in helper, (
            "a full refresh must clear the running flag so a fresh scan is "
            "guaranteed, the way Reload recreates the processes"
        )

    def test_poll_keeps_the_running_guard(self):
        text = read(REPO / "Panel.qml")
        helper = self._helper(text)
        assert "if (!proc.running) proc.running = true;" in helper, (
            "the 15s poll must not restart a slow scan already in flight"
        )
        assert helper.index("if (!keep)") < helper.index("if (!proc.running)"), (
            "the full-refresh restart must come before the poll guard"
        )

    def test_all_count_scans_go_through_the_helper(self):
        body = _refresh_games_body(read(REPO / "Panel.qml"))
        for proc in self.COUNT_PROCS:
            assert "restartGamingProc(" + proc + "," in body, (
                proc + " bypasses the full-refresh restart"
            )

    def test_full_refresh_still_resets_counts_to_minus_one(self):
        body = _refresh_games_body(read(REPO / "Panel.qml"))
        for prop in ("steamGameCount", "bnetGameCount", "prismInstanceCount",
                     "minecraftVersionCount", "heroicGameCount"):
            assert prop + " = -1;" in body, (
                prop + " is no longer reset, so recovery cannot tell it is unknown"
            )

    def test_recovery_targets_unresolved_counts_only(self):
        text = read(REPO / "Panel.qml")
        match = re.search(r"function recoverStalledCounts\(\) \{(.*?)\n  \}", text, re.S)
        assert match, "recoverStalledCounts() is missing"
        fn = match.group(1)
        for prop, proc in (
            ("steamGameCount", "steamManifestProc"),
            ("bnetGameCount", "bnetGameCountProc"),
            ("prismInstanceCount", "prismInstanceCountProc"),
            ("minecraftVersionCount", "minecraftVersionCountProc"),
            ("heroicGameCount", "heroicGameCountProc"),
        ):
            assert prop + " === -1 && !" + proc + ".running" in fn, (
                prop + " has no unresolved-and-idle recovery guard"
            )
            assert proc + ".running = true;" in fn, (
                proc + " is never re-requested after a silent exit"
            )

    def test_recovery_runs_on_open_and_poll(self):
        body = _refresh_games_body(read(REPO / "Panel.qml"))
        assert "recoverStalledCounts();" in body, (
            "recovery must run from refreshGames so both open (full refresh) "
            "and the 15s poll get it"
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


class TestConfigReadFailureIsVisible:
    """A config read failure must not be mistaken for a first run.

    configReadProc used `[ -f "$1" ] && cat "$1"`, so a file that exists but
    could not be read produced empty output. That parsed as "empty" and opened
    the first-run wizard. At startup configReady is false, so the wizard has no
    Cancel button and Save would overwrite a good config with the hostname.
    The command now emits a marker and the handler returns before the wizard.
    """

    def _handler(self):
        text = read(REPO / "Panel.qml")
        match = re.search(r"id:\s*configReadProc", text)
        assert match, "no configReadProc"
        # The stdout handler runs to the next `stderr:` at the same depth.
        end = text.find("stderr:", match.start())
        assert end > match.start(), "configReadProc has no stderr block"
        return text[match.start():end]

    def test_read_uses_the_classifier(self):
        handler = self._handler()
        assert "Config.readOutcome(" in handler, (
            "configReadProc must classify the read with Config.readOutcome"
        )
        assert "Config.readCommand(" in handler, (
            "configReadProc must use Config.readCommand, which reports a "
            "read failure instead of returning empty output"
        )

    def test_unreadable_returns_before_the_wizard(self):
        handler = self._handler()
        assert 'outcome === "unreadable"' in handler, (
            "the handler must branch on an unreadable config"
        )
        unreadable = handler.index('outcome === "unreadable"')
        # The branch must return before openWizard is reached.
        wizard = handler.find("openWizard")
        assert wizard == -1 or unreadable < wizard, (
            "an unreadable config must be handled before openWizard"
        )
        window = handler[unreadable:wizard if wizard != -1 else len(handler)]
        assert "return" in window, (
            "the unreadable branch must return so the wizard is not opened"
        )
        assert "notifyIfClosed" in window, (
            "a read failure must be visible even when the panel is closed"
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


class TestModelReferencesResolve:
    """A QML file may only call model functions that are actually exported.

    The model layer is imported per-file with an alias:

        import "model/Shell.mjs" as Shell

    so `Shell.trim(...)` resolves only if Shell.mjs exports `trim`. A typo, or
    a rename that missed one caller, fails at runtime in whichever tab renders
    that line — the panel opens, the tab is blank or throws, and nothing says
    why. TestNoDeadModelExports checks the other direction (every export has a
    caller); this checks that every call has an export.
    """

    # `watchedFiles` is a list of path strings like "model/Shell.mjs", which
    # would otherwise read as `Shell.mjs` member access.
    _MEMBER_ALLOWED = {"mjs"}

    @staticmethod
    def _exports():
        exports = {}
        for path in sorted((REPO / "model").glob("*.mjs")):
            text = read(path)
            exports[path.stem] = (
                set(re.findall(r"^export function (\w+)\(", text, re.M))
                | set(re.findall(r"^export const (\w+) =", text, re.M))
                | set(re.findall(r"^export class (\w+)", text, re.M))
            )
        return exports

    @staticmethod
    def _scannable(text):
        """Drop imports, comments and the watchedFiles path list."""
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
        kept = []
        in_watched = False
        for line in text.splitlines():
            stripped = line.lstrip()
            if stripped.startswith("import ") or stripped.startswith("//"):
                continue
            if "watchedFiles:" in line:
                in_watched = True
            if in_watched:
                if "]" in line:
                    in_watched = False
                continue
            kept.append(re.sub(r"//.*$", "", line))
        return "\n".join(kept)

    def _bad_references(self, text, exports):
        aliases = {
            match.group(2): Path(match.group(1)).stem
            for match in re.finditer(r'import\s+"([^"]+\.mjs)"\s+as\s+(\w+)', text)
        }
        body = self._scannable(text)
        problems = []
        for alias, stem in aliases.items():
            available = exports.get(stem, set())
            for match in re.finditer(r"\b" + re.escape(alias) + r"\.(\w+)", body):
                member = match.group(1)
                if member in self._MEMBER_ALLOWED:
                    continue
                if member not in available:
                    problems.append("%s.%s (not exported by %s.mjs)" % (alias, member, stem))
        return sorted(set(problems))

    def test_every_model_call_has_an_export(self):
        exports = self._exports()
        problems = []
        for path in QML_FILES:
            for problem in self._bad_references(read(path), exports):
                problems.append(relative(path) + ": " + problem)
        assert not problems, (
            "QML calls a model member that does not exist. It will fail when "
            "that tab renders:\n  " + "\n  ".join(problems)
        )

    def test_the_guard_would_catch_a_bad_call(self):
        # Mutation check in memory: a plausible-looking call to a member that
        # is not exported must be reported.
        exports = self._exports()
        sample = (
            'import "model/Shell.mjs" as Shell\n'
            "Item { property string x: Shell.trimOrPanic('a') }\n"
        )
        problems = self._bad_references(sample, exports)
        assert any("trimOrPanic" in problem for problem in problems), (
            "the detector did not flag a call to a non-existent model member"
        )
        # And a real call must not be flagged.
        good = 'import "model/Shell.mjs" as Shell\nItem { property string x: Shell.trim("a") }\n'
        assert not self._bad_references(good, exports)


class TestHubReferencesResolve:
    """Every `hub.<name>` in the UI must exist on the panel backend.

    Tabs reach the backend through the `hub` property, so `hub.dockerBusy` is a
    plain property lookup. QML does not fail a build over an unknown member: it
    binds to undefined, and qmllint only warns ("Unqualified access"), which is
    already noise here. A typo or a rename that missed one binding therefore
    renders a control that silently never updates — no error, no clue.

    This is the same shape as TestModelReferencesResolve, one layer up: that
    checks `Alias.member` against module exports, this checks `hub.member`
    against the panel's own properties and functions.
    """

    # Only root-level members count. Panel.qml's own properties and functions
    # sit at exactly two spaces of indentation; anything deeper belongs to a
    # child component and is not part of the hub surface.
    _MEMBER = re.compile(
        r"^  (?:readonly\s+)?(?:property\s+\S+\s+|function\s+)(\w+)", re.M
    )

    @staticmethod
    def _surface():
        text = read(REPO / "Panel.qml")
        return set(TestHubReferencesResolve._MEMBER.findall(text))

    @staticmethod
    def _scannable(text):
        """Drop comments and string literals.

        A URL such as "https://hub.docker.com" contains `hub.docker` and would
        otherwise read as a property reference. This was a real false positive
        when the guard was first written, so it is pinned by a test below.
        """
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
        text = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
        text = re.sub(r"'(?:\\.|[^'\\])*'", "''", text)
        return "\n".join(
            re.sub(r"//.*$", "", line) for line in text.splitlines()
        )

    def _bad_references(self, text, surface):
        body = self._scannable(text)
        problems = [
            match.group(1)
            for match in re.finditer(r"\bhub\.(\w+)", body)
            if match.group(1) not in surface
        ]
        return sorted(set(problems))

    def test_every_hub_reference_exists(self):
        surface = self._surface()
        assert "dockerContainers" in surface and "refreshAll" in surface, (
            "the hub surface was parsed as empty or partial"
        )
        problems = []
        for path in QML_FILES:
            for name in self._bad_references(read(path), surface):
                problems.append(relative(path) + ": hub." + name)
        assert not problems, (
            "the UI reads a hub member that Panel.qml does not define. The "
            "binding will be undefined with no error:\n  " + "\n  ".join(problems)
        )

    def test_the_guard_would_catch_a_typo(self):
        surface = self._surface()
        typo = "Item { Text { text: hub.dockerContianers.length } }"
        assert self._bad_references(typo, surface) == ["dockerContianers"], (
            "the detector did not flag a misspelled hub member"
        )
        good = "Item { Text { text: hub.dockerContainers.length } }"
        assert not self._bad_references(good, surface)

    def test_a_url_is_not_read_as_a_reference(self):
        surface = self._surface()
        # "https://hub.docker.com" is a string, not a property lookup.
        url = 'Item { function f() { return "https://hub.docker.com" } }'
        assert not self._bad_references(url, surface), (
            "a URL inside a string was misread as hub.docker"
        )


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
        check = body.find("if (!openExternalUrl(")
        assert check >= 0, name + " must check whether a browser opened"
        hand_off = body.find("handOffToExternalSurface()")
        assert hand_off > check, (
            name + " must only close the hub once the browser opened"
        )

    def test_open_external_url_checks_the_result(self):
        # One helper owns the check so no call site can drift back to an
        # unchecked Qt.openUrlExternally.
        body = self._fn("openExternalUrl")
        assert "Qt.openUrlExternally(" in body
        assert "if (Qt.openUrlExternally(" in body, (
            "openExternalUrl must branch on the return value"
        )
        assert "notify(" in body, "a browser failure must notify"
        assert "return false" in body, "openExternalUrl must report failure"

    def test_tabs_do_not_call_open_url_externally_directly(self):
        # Every browser launch goes through the helper, so the return value is
        # always checked and a failure is always surfaced.
        for rel in sorted(REPO.glob("ui/**/*.qml")):
            text = read(rel)
            for i, line in enumerate(text.splitlines(), 1):
                if "Qt.openUrlExternally(" in line:
                    raise AssertionError(
                        str(rel.relative_to(REPO)) + ":" + str(i) +
                        " calls Qt.openUrlExternally directly; use the hub helper"
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
        # notify() enqueues; _drainNotify() is what actually builds and runs
        # the command, so the helper check belongs there.
        text = self._panel()
        body = text[text.index("function _drainNotify()") :]
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


class TestMutualExclusionIsVisible:
    """The UI must show that installs and updates cannot run together.

    The functions refuse, but a button that stays enabled and then quietly
    does nothing is the dead-button problem again. Every entry point that
    starts an install or an update is disabled while the other runs.
    """

    def _read(self, rel):
        return read(REPO / rel)

    INSTALL_ENTRY_POINTS = [
        "hub.installExtraApp(",
        "hub.installSteam(",
        "hub.runDevInstallSilent(",
        "hub.openDevInstallTerminal(",
        "hub.runInstallInTerminal(",
    ]

    def _install_buttons(self, rel, install_flag):
        """Yield (enabled line, handler) for buttons that start an install.

        Buttons that stop tracking or clear the log are not install entry
        points and must not be checked for the other flag.
        """
        lines = self._read(rel).splitlines()
        for i, line in enumerate(lines):
            if "enabled:" not in line or install_flag not in line:
                continue
            # The handler may be a one-liner or a block, so scan a window
            # rather than just the onClicked line. Match the calls that start
            # an install specifically: `hub.installLog` and `hub.installRunning`
            # appear all over the log panel and would match a loose pattern.
            window = "\n".join(lines[i : i + 8])
            if any(call in window for call in self.INSTALL_ENTRY_POINTS):
                yield line, window

    def test_games_install_buttons_check_both(self):
        found = list(self._install_buttons("ui/tabs/GamesTab.qml", "hub.installRunning"))
        assert found, "no Games install buttons found"
        for line, handler in found:
            assert "omarchyUpdateRunning" in line, (
                "a Games install button ignores a running update: " + line.strip()
            )

    def test_games_install_buttons_exist_in_both_sections(self):
        # The Games tab renders the install log twice; keep the guard honest
        # if one of those sections loses its button.
        found = list(self._install_buttons("ui/tabs/GamesTab.qml", "hub.installRunning"))
        assert len(found) >= 2, "expected install buttons in both Games sections"

    def test_dev_install_buttons_check_both(self):
        text = self._read("ui/tabs/DevTab.qml")
        for line in text.splitlines():
            if "enabled: !hub.devInstallBusy && !hub.installRunning" in line:
                assert "omarchyUpdateRunning" in line, (
                    "a Dev install button ignores a running update: " + line.strip()
                )

    def test_update_button_checks_installs(self):
        text = self._read("ui/tabs/OverviewTab.qml")
        match = re.search(r"onClicked:\s*hub\.runOmarchyUpdateInPanel\(\)", text)
        assert match, "update button not found"
        # The enabled binding sits just above the handler.
        window = text[max(0, match.start() - 600) : match.start()]
        assert "enabled: !hub.omarchyUpdateRunning && !hub.installRunning" in window, (
            "the Update Omarchy button must be disabled while an install runs"
        )


class TestBackgroundActionFailuresAreVisible:
    """A Docker pull takes minutes and a stop can take ten seconds.

    The user can start one and close the hub before it finishes. Its failure
    would then only set lastActionMessage (shown as a toast) or a result field,
    neither of which is visible while the panel is closed. These actions must
    notify when the panel is closed, and stay quiet when it is open so the toast
    is not duplicated by a desktop notification.
    """

    def test_notify_if_closed_only_fires_when_closed(self):
        text = read(REPO / "Panel.qml")
        match = re.search(r"function notifyIfClosed\(text\)\s*\{", text)
        assert match, "no notifyIfClosed() helper"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    body = text[start : i + 1]
                    break
        else:
            raise AssertionError("unbalanced notifyIfClosed")
        assert "!root.opened" in body, "notifyIfClosed must guard on !root.opened"
        assert "root.notify(text)" in body, "notifyIfClosed must call notify()"

    @pytest.mark.parametrize(
        "anchor",
        [
            # dockerActionProc: start/stop/restart (stop can take ~10s)
            "dockerActionProc.stderr.text);",
            # dockerPullProc: minutes
            'root.dockerPullResult = "Pull failed for " + image +',
            # dockerPruneProc: can take a while
            '"Docker prune failed (code " + code + ")"',
            # codeServerActionProc: start/stop/uninstall
            '"VS Code Server " + actionName + " failed"',
            # pluginUpdateFetchProc: a git fetch can outlive the hub
            '"git fetch failed (code " + code + ")."',
            # pluginUpdatePullProc: a git pull can outlive the hub
            '"git pull failed (code " + code + ")."',
            # pluginUpdatePullProc success: "complete, now reload" needs saying
            'root.pluginUpdateStatus = "Update complete. Reload the hub to apply changes.";',
        ],
    )
    def test_failure_branch_notifies_when_closed(self, anchor):
        text = read(REPO / "Panel.qml")
        at = text.find(anchor)
        assert at >= 0, "anchor not found: " + anchor
        window = text[at : at + 400]
        assert "notifyIfClosed" in window, (
            "a background action failure must call notifyIfClosed so it is "
            "visible when the hub is closed: " + anchor
        )


class TestNotificationsAreQueued:
    """A burst of notifications must not drop any.

    `notify()` used to reuse one Process: it set `running = false`, changed the
    command and started it again. A second notification arriving while the
    first was still sending killed the first. When the hub is closed the
    notification is the only feedback, so a dropped one is invisible.
    """

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

    def test_notify_enqueues_instead_of_restarting(self):
        body = self._fn("notify")
        assert "notifyProc.running = false" not in body, (
            "notify must not kill an in-flight notification"
        )
        assert "_drainNotify()" in body, "notify must drain the queue"
        assert "_notifyQueue" in body, "notify must enqueue the message"

    def test_drain_guards_the_running_process(self):
        body = self._fn("_drainNotify")
        assert "if (notifyProc.running) return;" in body, (
            "_drainNotify must not start a second process"
        )
        assert "notifyProc.running = true" in body

    def test_drain_runs_on_exit(self):
        text = self._panel()
        match = re.search(r"^\s*id:\s*notifyProc\s*$", text, re.M)
        assert match, "notifyProc not found"
        start = text.rfind("Process {", 0, match.start())
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    block = text[start : i + 1]
                    break
        else:
            raise AssertionError("unbalanced notifyProc block")
        assert "_drainNotify()" in block, (
            "notifyProc.onExited must drain the queue"
        )


class TestServersSubTabs:
    """Servers has its own sub-nav: list, create and logs are separate views."""

    def _servers_column(self, text):
        start = text.index('visible: panel.gamesSubTab === "servers"')
        end = text.index('// Storage tab', start)
        return text[start:end]

    def test_three_sub_tabs_are_wired(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert 'property string serversSubTab: "list"' in text
        body = self._servers_column(text)
        for view in ("list", "create", "logs"):
            assert 'serversSubTab = "' + view + '"' in body, (
                view + " has no sub-nav button"
            )

    def test_each_view_has_a_visibility_gate(self):
        body = self._servers_column(read(REPO / "ui/tabs/GamesTab.qml"))
        for view in ("list", "create", "logs"):
            assert 'visible: serversSubTab === "' + view + '"' in body, (
                view + " is not gated, so it will render on every sub-tab"
            )

    def test_logs_action_opens_the_logs_tab(self):
        body = self._servers_column(read(REPO / "ui/tabs/GamesTab.qml"))
        match = re.search(
            r"hub\.showMinecraftServerLogs\(modelData\.name\);(.*?)\}", body, re.S
        )
        assert match, "the row Logs action no longer calls showMinecraftServerLogs"
        assert 'serversSubTab = "logs"' in match.group(1), (
            "clicking Logs must open the Logs sub-tab, or nothing appears to happen"
        )

    def test_closing_logs_returns_to_the_list(self):
        body = self._servers_column(read(REPO / "ui/tabs/GamesTab.qml"))
        match = re.search(
            r"hub\.clearMinecraftServerLogs\(\);(.*?)\}", body, re.S
        )
        assert match, "the log Close action is missing"
        assert 'serversSubTab = "list"' in match.group(1)

    def test_detection_comes_from_the_shared_model(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        assert 'import "../../model/Gaming.mjs" as Gaming' in text
        assert "Gaming.gameServerContainers(" in text
        assert '"steamcmd"' not in text, (
            "the keyword list must live in Gaming.mjs, not duplicated in QML"
        )


class TestGameServerStorageCard:
    """Storage reports both sizes for the same servers the Servers tab lists."""

    def test_panel_has_size_state_process_and_refresh(self):
        text = read(REPO / "Panel.qml")
        for declaration in (
            "property var gameServerSizes: []",
            "property bool gameServerSizesBusy: false",
            'property string gameServerSizesError: ""',
        ):
            assert declaration in text, declaration
        assert "function refreshGameServerSizes()" in text
        assert "Gaming.gameServerContainers(dockerContainers, steamDedicatedServers)" in text
        assert "Gaming.gameServerSizeCommand(servers)" in text
        assert "id: gameServerSizesProc" in text
        assert "Gaming.parseGameServerSizes(text)" in text

    def test_sizes_are_not_on_the_poll_path(self):
        text = read(REPO / "Panel.qml")
        assert "refreshGameServerSizes()" not in _refresh_games_body(text), (
            "du walks each world folder; the 15s poll must not re-run it"
        )

    def test_storage_queries_on_open_and_has_refresh(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        start = text.index('visible: panel.gamesSubTab === "storage"')
        body = text[start:]
        assert "onVisibleChanged: if (visible) hub.refreshGameServerSizes()" in body
        assert "hub.refreshGameServerSizes()" in body
        assert "Game server storage" in body

    def test_reopening_on_storage_refreshes(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        match = re.search(r"function onOpenedChanged\(\) \{(.*?)\n  \}", text, re.S)
        assert match, "no open-time refresh hook in GamesTab"
        assert "panel.gamesSubTab === \"storage\"" in match.group(1)
        assert "hub.refreshGameServerSizes()" in match.group(1)

    def test_both_size_figures_are_rendered(self):
        body = read(REPO / "ui/tabs/GamesTab.qml")
        assert "modelData.dataSize" in body
        assert "modelData.containerSize" in body
        assert "modelData.path" in body


class TestGameServersLayoutAndBlueSlice:
    """Server data has one home; Storage shows it as a visible blue slice."""

    def _storage_body(self):
        text = read(REPO / "ui/tabs/GamesTab.qml")
        return text[text.index('visible: panel.gamesSubTab === "storage"'):]

    def test_wizard_derives_one_data_dir_per_server_name(self):
        docker = read(REPO / "model/Docker.mjs")
        panel = read(REPO / "Panel.qml")
        wizard = read(REPO / "ui/MinecraftServerWizard.qml")
        assert "/mnt/games/GameServers" in docker
        assert 'minecraftDataDir(name, baseDir)' in docker
        assert 'mcServerDataDirDraft: gameMount + "/GameServers/vember-minecraft-data"' in panel
        assert 'mcServerDataDirAutoName: "vember-minecraft"' in panel
        assert "function mcWizardNameChanged(name)" in panel
        assert panel.count('defaultDataDir: gameMount + "/GameServers"') == 2
        assert "onTextChanged: panel.hub.mcWizardNameChanged(text)" in wizard
        assert "onTextEdited:" in wizard
        # Each server must bind its own /data; a fixed shared path is the bug.
        assert '"/GameServers/Minecraft"' not in panel
        assert "minecraft-servers" not in panel
        assert "/var/minecraft-servers" not in docker

    def test_panel_tracks_total_server_bytes(self):
        panel = read(REPO / "Panel.qml")
        assert "property int gameServerDataBytes: 0" in panel
        assert "Gaming.gameServerTotalBytes(root.gameServerSizes)" in panel
        assert "gameServerDataBytes = 0;" in panel, "clearing sizes must clear the bar"
        assert "gameServerDataBytes: root.gameServerDataBytes" in panel

    def test_size_query_emits_raw_bytes(self):
        gaming = read(REPO / "model/Gaming.mjs")
        assert "du -sb" in gaming
        assert "dbytes=$(du -sb" in gaming, "the fifth field must reach the parser"
        assert "export function gameServerTotalBytes" in gaming

    def test_storage_bar_has_blue_slice_with_minimum(self):
        body = self._storage_body()
        assert 'color: "#3b82f6"' in body, "no blue slice on the partition bar"
        assert "Math.max(6, usedPx * serverShare)" in body, "blue would be sub-pixel"
        assert "partitionBar.usedPx - partitionBar.bluePx" in body, "rest of used space is not drawn"
        assert "panel.storageUseColor(hub.gameMountUseRatio)" in body

    def test_blue_legend_prints_real_size_and_percentage(self):
        body = self._storage_body()
        assert "Shell.humanBytes(hub.gameServerDataBytes)" in body
        assert "(partitionBar.serverShare * 100).toFixed(2)" in body
        assert "% of used space (blue)" in body
        assert "visible: hub.gameServerDataBytes > 0" in body

    def test_bar_widths_do_not_form_a_cycle(self):
        body = self._storage_body()
        assert "id: partitionBar" in body
        assert "property real usedPx: partitionBar.width" in body, (
            "segment widths must not feed back into the track"
        )
        match = re.search(r"property real usedPx: partitionBar\.width", body)
        assert match, "no proportional width binding"
        assert "width: parent.width\n                height: 12" in body, (
            "track width must come from its layout parent"
        )


class TestContainerWebLinks:
    """Containers with a published web port get a one-click browser button."""

    def test_panel_opens_only_http_urls_and_hands_off(self):
        panel = read(REPO / "Panel.qml")
        assert "function openContainerWebUrl(url, name)" in panel
        start = panel.index("function openContainerWebUrl(url, name)")
        body = panel[start:start + 900]
        assert "http" in body and "https" in body
        assert "openExternalUrl(target" in body
        assert "handOffToExternalSurface()" in body
        assert "notify(lastActionMessage)" in body

    def test_row_and_detail_buttons_are_wired(self):
        text = read(REPO / "ui/tabs/ContainersTab.qml")
        assert text.count("panel.hub.openContainerWebUrl(") >= 2, (
            "both the row and the detail panel need a one-click action"
        )
        assert 'visible: Shell.trim(modelData.webUrl || "").length > 0' in text
        assert "containerDetails.selected.webUrl" in text
        assert "󰕮" in text

    def test_ps_poll_supplies_the_ports(self):
        docker = read(REPO / "model/Docker.mjs")
        assert "{{.Ports}}" in docker
        assert "webUrl: self.webUrlFromPorts(" in docker


class TestComposeApplyUpdate:
    """Pulling an image is not enough; apply recreates the Compose service."""

    def test_model_exports_are_wired_into_the_panel_chain(self):
        docker = read(REPO / "model/Docker.mjs")
        panel = read(REPO / "Panel.qml")
        for fn in ("inspectComposeCommand", "parseComposeInfo",
                   "applyComposeUpdateCommand"):
            assert "export function " + fn in docker
            assert "Docker." + fn + "(" in panel, fn + " is never called"

    def test_apply_uses_no_deps_and_project_directory(self):
        docker = read(REPO / "model/Docker.mjs")
        assert '"-p", c.project, "up", "-d", "--no-deps", c.service' in docker
        assert '"--project-directory", c.workingDir' in docker

    def test_two_step_process_chain(self):
        panel = read(REPO / "Panel.qml")
        assert "function startApplyComposeUpdate(name)" in panel
        assert "id: dockerComposeInspectProc" in panel
        assert "id: dockerComposeApplyProc" in panel
        start = panel.index("id: dockerComposeInspectProc")
        end = panel.index("id: dockerComposeApplyProc")
        chain = panel[start:end]
        assert "Docker.parseComposeInfo(" in chain
        assert "not managed by Compose" in chain
        assert "dockerComposeApplyProc.running = true" in chain
        # Both failure exits of the inspect step must release the global guard,
        # or every Docker action stays disabled after a rejected apply.
        assert chain.count("root.dockerBusy = false") >= 2
        apply = panel[end:]
        assert "root.dockerBusy = false" in apply[:900]
        assert "root.refreshDocker()" in apply[:1600]

    def test_confirmation_dialog_and_button(self):
        hub = read(REPO / "HubPanel.qml")
        assert "property bool confirmApplyUpdate: false" in hub
        assert "property string applyUpdateTarget" in hub
        assert "ApplyUpdateConfirmDialog { panel: panel; cardRadius: card.radius }" in hub
        dialog = read(REPO / "ui/ApplyUpdateConfirmDialog.qml")
        assert "startApplyComposeUpdate(panel.applyUpdateTarget)" in dialog
        tabs = read(REPO / "ui/tabs/ContainersTab.qml")
        assert "panel.applyUpdateTarget = containerDetails.selected.name" in tabs
        assert "panel.confirmApplyUpdate = true" in tabs
        assert 'text: "Apply update"' in tabs

    def test_apply_result_exposed_for_verification(self):
        panel = read(REPO / "Panel.qml")
        assert "dockerApplyName: root.dockerApplyName" in panel
        assert "dockerApplyStatus: root.dockerApplyStatus" in panel
        assert "dockerApplyResult: root.dockerApplyResult" in panel


class TestMinecraftDirectLaunch:
    """Both client launches use clean Prism instances with distinct targets."""

    def test_model_helper_is_wired(self):
        model = read(REPO / "model/Gaming.mjs")
        panel = read(REPO / "Panel.qml")
        assert "export function minecraftClientLaunchCommand" in model
        assert "export function minecraftClientInstalled" in model
        assert "Gaming.minecraftClientLaunchCommand(which)" in panel

    def test_panel_launch_process_hands_off(self):
        panel = read(REPO / "Panel.qml")
        assert "function launchMinecraftClient(mode)" in panel
        start = panel.index("function launchMinecraftClient(mode)")
        body = panel[start:start + 900]
        assert '=== "server" ? "server" : "vanilla"' in body
        assert "mcClientLaunchProc.running = true" in body
        assert "handOffToExternalSurface()" in body
        assert "id: mcClientLaunchProc" in panel

    def test_join_buttons_are_dynamic_and_vanilla_is_kept(self):
        tabs = read(REPO / "ui/tabs/GamesTab.qml")
        assert "hub.launchMinecraftServer(modelData.name, modelData.port" in tabs
        assert 'hub.launchMinecraftClient("vanilla")' in tabs
        assert "Gaming.minecraftClientInstalled(hub.extraApps" in tabs
        assert 'text: "Plain vanilla"' in tabs
        assert "Join Vember server" not in tabs

    def test_status_exposes_launch_state(self):
        panel = read(REPO / "Panel.qml")
        assert "mcClientLaunchStatus: root.mcClientLaunchStatus" in panel


class TestModpackAndServerListWiring:
    def test_wizard_offers_installed_modpacks(self):
        wizard = read(REPO / "ui/MinecraftServerWizard.qml")
        assert 'label: "Installed modpack"' in wizard
        assert "options: panel.hub.mcWizardModpackOptions" in wizard
        assert "onChanged: panel.hub.mcWizardChooseModpack(value)" in wizard

    def test_panel_wires_modpack_scan_and_server_list(self):
        text = read(REPO / "Panel.qml")
        for name in (
            "id: mcWizardModpackScanProc", "id: mcServerListProc",
            "id: mcServerListDelayTimer", "function refreshMinecraftServerList(address)",
            "function mcWizardChooseModpack(id)",
            "Gaming.minecraftJoinGameDirs(homeDir)",
            "Wizard.modpackScanCommand(homeDir)",
        ):
            assert name in text, name + " is missing"
        assert "modsDir: mcWizardModsDir, worldDir: mcWizardWorldDir" in text

    def test_modpack_config_is_staged_before_creation(self):
        panel = read(REPO / "Panel.qml")
        for name in (
            "property string mcWizardSupportDir: \"\"",
            "mcWizardSupportDir = m.supportDir || \"\"",
            "Docker.stageModpackDataCommand(normalized.dataDir, mcWizardSupportDir)",
            "id: mcServerStageProc",
            "root._mcPendingCreateCommand",
        ):
            assert name in panel, name + " is missing"

    def test_successful_creation_confirms_and_closes_the_wizard(self):
        panel = read(REPO / "Panel.qml")
        assert "\"Success: \" + root.mcServerNameDraft" in panel
        assert "root.notify(root.mcServerCreateResult);" in panel
        assert "root.closeMinecraftServerWizard();" in panel
        wizard = read(REPO / "ui/MinecraftServerWizard.qml")
        assert "panel.hub.mcWizardSupportDir" in wizard

    def test_gaming_model_exports_the_server_list_helpers(self):
        text = read(REPO / "model/Gaming.mjs")
        assert "export function minecraftServerListCommand" in text
        assert "export function minecraftJoinGameDirs" in text


class TestPortPoolWiring:
    def test_wizard_offers_a_free_port_dropdown(self):
        wizard = read(REPO / "ui/MinecraftServerWizard.qml")
        assert 'label: "Port"' in wizard
        assert "options: panel.hub.mcWizardPortOptions" in wizard
        assert "onChanged: panel.hub.mcWizardSetPort(value)" in wizard
        assert "panel.hub.refreshMinecraftPorts()" in wizard
        assert "panel.hub.mcWizardPortNote" in wizard

    def test_panel_scans_and_reassigns_ports(self):
        panel = read(REPO / "Panel.qml")
        for name in (
            "id: mcPortScanProc",
            "function refreshMinecraftPorts()",
            "function recomputeMinecraftPorts()",
            "function mcWizardSetPort(port)",
            "Wizard.listeningPortsCommand()",
            "Wizard.portStatus(dockerContainers, mcWizardListeningText, mcServerPortDraft)",
        ):
            assert name in panel, name + " is missing"
        assert "if (root.mcWizardOpen) root.recomputeMinecraftPorts();" in panel
        assert "created on port \" + root.mcServerPortDraft" in panel

    def test_creation_result_no_longer_hardcodes_25565(self):
        panel = read(REPO / "Panel.qml")
        assert "Connect on port 25565" not in panel

    def test_creating_a_second_server_keeps_the_vember_join_entry(self):
        panel = read(REPO / "Panel.qml")
        assert "root.refreshMinecraftServerList(root.mcWizardJoinAddress)" not in panel


class TestOneClickLaunchWiring:
    def test_wizard_result_has_a_launch_button(self):
        wizard = read(REPO / "ui/MinecraftServerWizard.qml")
        assert "panel.hub.launchMinecraftServer(" in wizard
        assert "panel.hub.mcServerLaunchName" in wizard

    def test_servers_rows_have_a_launch_button(self):
        games = read(REPO / "ui/tabs/GamesTab.qml")
        assert 'text: "Launch"' in games
        assert "hub.launchMinecraftServer(" in games
        assert "Docker.publishedPorts(modelData.ports || \"\")" in games

    def test_panel_chains_prepare_start_wait_and_join(self):
        panel = read(REPO / "Panel.qml")
        for name in (
            "function launchMinecraftServer(name, port, sourceId, clientOverride)",
            "function prepareServerInstance()",
            "function refreshServerInstanceList()",
            "id: mcServerLaunchProc",
            'step = "start"',
            'step = "wait"',
            "Gaming.minecraftPortWaitCommand(",
            "Gaming.minecraftServerInstanceCommand(",
            "id: mcServerClientProc",
            "id: mcServerEntryDelayTimer",
        ):
            assert name in panel, name + " is missing"


class TestOverviewRedesign:
    """Overview's Docker and Games cards are quick-launch surfaces, not lists."""

    @staticmethod
    def _overview():
        return read(REPO / "ui/tabs/OverviewTab.qml")

    def test_docker_card_has_ui_pills_and_metrics(self):
        text = self._overview()
        for name in (
            "property var overviewWebUis",
            "panel.hub.openContainerWebUrl(ui.url, ui.name)",
            "Container RAM:",
            "Host CPU:",
            "GPU: n/a",
        ):
            assert name in text, name + " is missing"

    def test_games_card_has_launch_slices_and_one_count(self):
        text = self._overview()
        for name in (
            "Quick launch",
            "property var overviewLaunchServers",
            'panel.hub.launchMinecraftServer(server.name, server.port, "")',
            'overviewInstalledGames + " games installed"',
        ):
            assert name in text, name + " is missing"
        assert "Steam: " not in text and "Battle.net: " not in text

    def test_storage_is_its_own_card(self):
        text = self._overview()
        assert "Games storage" in text
        assert "id: glanceSt" in text
        assert "Shell.humanBytes(hub.gameMountTotalBytes)" in text

    def test_panel_samples_docker_stats_and_host_cpu(self):
        panel = read(REPO / "Panel.qml")
        for name in (
            "property real containerRamBytes: -1",
            "property real hostCpuPercent: -1",
            "function refreshMetrics()",
            "id: dockerStatsProc",
            "id: hostMetricsProc",
            "Docker.statsCommand()",
            "SystemInfo.hostMetricsCommand()",
        ):
            assert name in panel, name + " is missing"


class TestGameServerRemoval:
    """A destructive per-server action must be named, confirmed and narrow."""

    @staticmethod
    def _body(text, name):
        match = re.search(r"function\s+" + name + r"\s*\([^)]*\)\s*\{", text)
        assert match, name + " not found"
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

    def test_backend_keeps_the_target_and_result(self):
        panel = read(REPO / "Panel.qml")
        assert "property string gameServerRemoveTarget: \"\"" in panel
        assert "property string gameServerRemoveResult: \"\"" in panel

    def test_open_dialog_keeps_the_name_not_an_index(self):
        backend = self._body(read(REPO / "Panel.qml"), "openGameServerRemoveDialog")
        assert "gameServerRemoveTarget = target" in backend
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        assert "hub.openGameServerRemoveDialog(modelData.name)" in tab
        assert "panel.confirmRemoveGameServer = true" in tab

    def test_confirm_uses_the_narrow_command_and_global_busy_guard(self):
        body = self._body(read(REPO / "Panel.qml"), "removeGameServer")
        assert "Docker.removeGameServerCommand(target)" in body
        assert "dockerBusy = true" in body
        assert "gameServerRemoveProc.running = true" in body
        dialog = read(REPO / "ui" / "GameServerRemoveDialog.qml")
        assert "panel.confirmRemoveGameServer = false" in dialog

    def test_finish_refreshes_every_view_of_the_removed_server(self):
        panel = read(REPO / "Panel.qml")
        start = panel.index("id: gameServerRemoveProc")
        end = panel.index("// Keeps the Vember server visible in Prism", start)
        block = panel[start:end]
        for needle in (
            "root.dockerBusy = false",
            "root.gameServerRemoveTarget = \"\"",
            "root.gameServerRemoveResult =",
            "root.notify(root.lastActionMessage)",
            "root.refreshDocker()",
            "root.refreshGames()",
            "root.refreshGameServerSizes()",
        ):
            assert needle in block, needle + " missing from removal completion"

    def test_hub_panel_owns_and_resets_the_dialog(self):
        text = read(REPO / "HubPanel.qml")
        assert "property bool confirmRemoveGameServer: false" in text
        assert "panel.confirmRemoveGameServer = false" in text
        assert "hub.closeGameServerRemoveDialog()" in text
        assert "GameServerRemoveDialog { panel: panel; cardRadius: card.radius }" in text

    def test_remove_button_is_on_docker_rows_only(self):
        text = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        assert "text: \"Remove\"" in text
        assert "hub.openGameServerRemoveDialog(modelData.name)" in text
        assert "enabled: !hub.dockerBusy" in text
        assert "hub.gameServerRemoveResult" in text

    def test_dialog_states_the_exact_scope(self):
        text = read(REPO / "ui" / "GameServerRemoveDialog.qml")
        for needle in (
            "panel.hub.closeGameServerRemoveDialog()",
            "panel.hub.removeGameServer()",
            "Data folder to delete:",
            "Prism instances and modpack files are kept.",
            "enabled: !panel.hub.dockerBusy",
        ):
            assert needle in text, needle + " missing from removal dialog"


class TestMinecraftServerEditing:
    """Name, port and mod changes recreate the container around the same data dir."""

    @staticmethod
    def _body(text, name):
        match = re.search(r"function\s+" + name + r"\s*\([^)]*\)\s*\{", text)
        assert match, name + " not found"
        start = text.index("{", match.end() - 1)
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    return text[start:i + 1]
        raise AssertionError("unbalanced braces in " + name)

    def test_backend_declares_edit_state_and_all_five_processes(self):
        panel = read(REPO / "Panel.qml")
        for needle in (
            'property string mcEditOldName: ""',
            'property string mcEditNameDraft: ""',
            'property int mcEditPortDraft: 0',
            'property string mcEditMemoryDraft: "4G"',
            'property bool mcEditMemoryModded: false',
            'property string mcEditStatus: ""',
            'property string mcEditResult: ""',
            "id: mcEditInspectProc", "id: mcEditModpackScanProc",
            "id: mcEditModsProc", "id: mcEditRecreateProc", "id: mcEditWaitProc",
        ):
            assert needle in panel, needle + " missing from backend"

    def test_open_inspects_the_container_and_scans_modpacks(self):
        body = self._body(read(REPO / "Panel.qml"), "openMinecraftServerEditDialog")
        assert "Docker.inspectMinecraftServerCommand(old)" in body
        assert "Wizard.modpackScanCommand(homeDir)" in body
        assert "mcEditNameDraft = old" in body
        assert 'mcEditMemoryDraft = "4G"' in body
        assert "mcEditMemoryModded = false" in body
        assert "mcEditResult = \"\"" in body

    def test_save_validates_before_refresh_and_recreate(self):
        body = self._body(read(REPO / "Panel.qml"), "saveMinecraftServerEdit")
        assert "Docker.recreateMinecraftServerCommand(old, opts)" in body
        assert "memory: mcEditMemoryDraft || s.memory" in body
        assert "Docker.refreshMinecraftModsCommand(" in body
        assert "return false" in body  # validation keeps the dialog open
        assert "return true" in body   # a started edit closes it

    def test_recreate_waits_for_a_real_status_ping(self):
        panel = read(REPO / "Panel.qml")
        assert "mcEditWaitProc.command = Gaming.minecraftPortWaitCommand(root.mcEditPortDraft, 90)" in panel
        assert 'var ready = Shell.trim(stdout.text) === "ready"' in panel
        assert "root.refreshDocker();" in panel
        assert "root.refreshGameServerSizes();" in panel

    def test_dialog_uses_the_backend_and_keeps_validation_errors_visible(self):
        dialog = read(REPO / "ui" / "MinecraftServerEditDialog.qml")
        for needle in (
            "visible: panel.confirmEditMinecraftServer",
            "if (panel.hub.saveMinecraftServerEdit())",
            "panel.confirmEditMinecraftServer = false",
            "panel.hub.mcEditSetName(text)",
            "panel.hub.mcEditSetPort(value)",
            "panel.hub.mcEditChooseModpack(value)",
            "panel.hub.mcEditSetMemory(value)",
            "Pull mods from Prism instance",
            "Docker cannot rename or republish a container in place",
        ):
            assert needle in dialog, needle + " missing from edit dialog"

    def test_row_edit_button_is_minecraft_only(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        assert "Gaming.isMinecraftContainer(modelData)" in tab
        assert "hub.openMinecraftServerEditDialog(" in tab
        assert 'text: "Edit"' in tab

    def test_edit_button_opens_the_dialog_not_just_the_status_message(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        row = tab.split('text: "Edit"', 1)[1].split('text: "Remove"', 1)[0]
        assert "hub.openMinecraftServerEditDialog(" in row
        assert "panel.confirmEditMinecraftServer = true;" in row

    def test_hubpanel_declares_resets_and_instantiates_the_dialog(self):
        hubpanel = read(REPO / "HubPanel.qml")
        assert "property bool confirmEditMinecraftServer: false" in hubpanel
        assert "panel.confirmEditMinecraftServer = false" in hubpanel
        assert "hub.closeMinecraftServerEditDialog()" in hubpanel
        assert "MinecraftServerEditDialog { panel: panel; cardRadius: card.radius }" in hubpanel


class TestDynamicMinecraftClientBar:
    """The Servers card builds join actions from detected servers, not literals."""

    def test_no_hardcoded_launcher_or_address(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        assert "Prism · clean" not in tab
        assert "vemberos:25565" not in tab
        assert "Join Vember server" not in tab

    def test_join_buttons_come_from_the_detected_server_list(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        assert "property var minecraftJoinServers: Gaming.minecraftServers(hub.dockerContainers || [])" in tab
        assert "model: gamesTabRoot.minecraftJoinServers || []" in tab
        assert '"Join " + (modelData.name || "server")' in tab
        assert "hub.launchMinecraftServer(modelData.name, modelData.port" in tab

    def test_plain_vanilla_still_opens_the_main_menu(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        assert 'text: "Plain vanilla"' in tab
        assert 'hub.launchMinecraftClient("vanilla")' in tab


class TestMinecraftClientTemplateWiring:
    """Template setup lives in the hub; the client choice is visible in the UI."""

    def test_panel_sets_up_template_and_supports_client_override(self):
        panel = read(REPO / "Panel.qml")
        for name in (
            "function setupMinecraftPrism()",
            "function refreshMinecraftClientDefaults()",
            "function launchMinecraftServer(name, port, sourceId, clientOverride)",
            "function launchMinecraftOfficial()",
            "function saveMinecraftEditClient()",
            "id: mcPrismSetupProc",
            "id: mcClientDefaultsProc",
            'step = "official-list"',
            "Gaming.minecraftOfficialServerListCommand(",
            "Gaming.minecraftOfficialLaunchCommand(",
            "setupMinecraftPrism();",
        ):
            assert name in panel, name + " is missing"

    def test_gaming_tab_has_client_picker_and_official_button(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        for name in (
            'property string clientChoice: ""',
            '{ value: "", label: "Server default" }',
            '{ value: "prism", label: "Prism" }',
            '{ value: "official", label: "Official" }',
            'label: "Join with"',
            'text: "Official launcher"',
            "hub.launchMinecraftOfficial()",
            "gamesTabRoot.clientChoice)",
        ):
            assert name in tab, name + " is missing"

    def test_official_launcher_button_is_on_the_main_launcher_bar(self):
        tab = read(REPO / "ui" / "tabs" / "GamesTab.qml")
        bar = tab.split("// Launcher bar (installed launchers only)", 1)[1].split("Repeater {", 1)[0]
        assert 'text: "Official launcher"' in bar
        assert "hub.launchMinecraftOfficial()" in bar
        client = tab.split("// Client quick launch.", 1)[1].split("// Guided server creation.", 1)[0]
        assert 'text: "Official launcher"' not in client

    def test_panel_checks_official_launcher_at_startup(self):
        panel = read(REPO / "Panel.qml")
        assert "property bool mcOfficialInstalled: false" in panel
        assert "root.mcOfficialInstalled = found.official === true;" in panel
        on_completed = panel.split("Component.onCompleted: {", 1)[1].split("}", 1)[0]
        assert "mcWizardClientCheckProc.running = true;" in on_completed

    def test_edit_dialog_has_join_from_dropdown(self):
        dialog = read(REPO / "ui" / "MinecraftServerEditDialog.qml")
        for name in (
            'label: "Join from"',
            "options: Wizard.clientOptions()",
            "onChanged: panel.hub.mcEditSetClient(value)",
        ):
            assert name in dialog, name + " is missing"

    def test_edit_dialog_has_memory_dropdown(self):
        dialog = read(REPO / "ui" / "MinecraftServerEditDialog.qml")
        for name in (
            'label: "Memory"',
            "value: panel.hub.mcEditMemoryDraft",
            "options: Wizard.memoryOptions(panel.hub.mcEditMemoryModded)",
            "onChanged: panel.hub.mcEditSetMemory(value)",
        ):
            assert name in dialog, name + " is missing"

    def test_reserved_instance_ids_are_not_user_facing(self):
        model = read(REPO / "model" / "Gaming.mjs")
        for name in (
            '"minecraft-server", "minecraft-join", "minecraft-vanilla",',
            '"server" ? "minecraft-join" : "minecraft-vanilla";',
        ):
            assert name in model, name + " is missing"
