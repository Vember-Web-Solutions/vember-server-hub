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
        hub = read(REPO / "HubPanel.qml")
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
            block = self._instantiation(name, hub)
            if block is None:
                problems.append("%s is never instantiated in HubPanel.qml" % name)
                continue
            for prop in required:
                if not re.search(r"\b" + prop + r"\s*:", block):
                    problems.append("%s requires %s but does not receive it" % (name, prop))
        assert not problems, "unsatisfied required properties:\n  " + "\n  ".join(problems)
