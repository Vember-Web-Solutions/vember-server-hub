"""Tests for model/Config.mjs: tab ordering that survives config drift."""

import json
import subprocess


class TestDefaults:
    def test_default_order_is_the_known_tab_strip(self, js):
        out = js("console.log(JSON.stringify(Config.defaultTabOrder()))")
        assert out == ["overview", "access", "containers", "games", "dev"]

    def test_default_is_a_copy_not_the_shared_array(self, js):
        # Mutating the returned array must not poison the next call.
        out = js(
            "var a = Config.defaultTabOrder(); a.push('junk');"
            "console.log(JSON.stringify(Config.defaultTabOrder()))"
        )
        assert "junk" not in out


class TestNormalize:
    def test_saved_order_is_respected(self, js):
        out = js(
            "console.log(JSON.stringify(Config.normalizedTabOrder("
            '["games","overview","dev","access","containers"])))'
        )
        assert out == ["games", "overview", "dev", "access", "containers"]

    def test_unknown_ids_are_dropped(self, js):
        out = js(
            'console.log(JSON.stringify(Config.normalizedTabOrder(["bogus","games"])))'
        )
        assert out == ["games", "overview", "access", "containers", "dev"]

    def test_missing_tabs_are_appended(self, js):
        # A config written before a tab existed must still yield every tab.
        out = js('console.log(JSON.stringify(Config.normalizedTabOrder(["dev"])))')
        assert out == ["dev", "overview", "access", "containers", "games"]

    def test_duplicates_collapse(self, js):
        out = js(
            'console.log(JSON.stringify(Config.normalizedTabOrder(["dev","dev","dev"])))'
        )
        assert out.count("dev") == 1
        assert len(out) == 5

    def test_null_and_empty_give_the_default(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Config.normalizedTabOrder(null), Config.normalizedTabOrder([])]))"
        )
        assert out == [
            ["overview", "access", "containers", "games", "dev"],
            ["overview", "access", "containers", "games", "dev"],
        ]

    def test_whitespace_and_non_strings_are_tolerated(self, js):
        out = js(
            'console.log(JSON.stringify(Config.normalizedTabOrder(["  games  ", 42, null])))'
        )
        assert out[0] == "games"
        assert len(out) == 5

    def test_result_always_contains_every_tab(self, js):
        out = js(
            "console.log(JSON.stringify(Config.normalizedTabOrder("
            '["nope","games","games","also-nope"])))'
        )
        assert sorted(out) == sorted(["overview", "access", "containers", "games", "dev"])


class TestParseHubConfig:
    """The four outcomes the panel maps onto its own state.

    "empty"   no file yet           -> ask for a name, keep editor/order/port
    "ready"   a name is configured  -> use everything, no wizard
    "wizard"  file exists, no name  -> ask for a name, keep the rest
    "invalid" unreadable JSON       -> reset to defaults, ask for a name
    """

    def parse(self, js, raw):
        # Pass through JSON so quotes and newlines survive the shell hop.
        return js(
            "console.log(JSON.stringify(Config.parseHubConfig(%s)))"
            % json.dumps(raw)
        )

    def test_missing_file_is_empty(self, js):
        assert self.parse(js, "") == {"state": "empty"}

    def test_whitespace_only_is_empty(self, js):
        assert self.parse(js, "  \n\t ") == {"state": "empty"}

    def test_complete_config_is_ready(self, js):
        out = self.parse(
            js,
            json.dumps(
                {
                    "serverName": "vemberos",
                    "serverRole": "NAS",
                    "preferredEditor": "code",
                    "tabOrder": ["dev", "games"],
                    "codeServerPort": 9443,
                }
            ),
        )
        assert out["state"] == "ready"
        assert out["serverName"] == "vemberos"
        assert out["serverRole"] == "NAS"
        assert out["preferredEditor"] == "code"
        assert out["codeServerPort"] == 9443
        # Saved order is respected, missing tabs are appended.
        assert out["tabOrder"][:2] == ["dev", "games"]
        assert len(out["tabOrder"]) == 5

    def test_config_without_a_name_asks_for_one(self, js):
        out = self.parse(js, json.dumps({"preferredEditor": "code"}))
        assert out["state"] == "wizard"
        assert out["serverName"] == ""
        # Everything else the file carried is preserved.
        assert out["preferredEditor"] == "code"

    def test_blank_name_counts_as_missing(self, js):
        out = self.parse(js, json.dumps({"serverName": "   "}))
        assert out["state"] == "wizard"

    def test_broken_json_resets_to_defaults(self, js):
        out = self.parse(js, "{not json")
        assert out["state"] == "invalid"
        assert out["serverName"] == ""
        assert out["serverRole"] == ""
        assert out["preferredEditor"] == ""
        assert out["codeServerPort"] == 8443
        assert out["tabOrder"] == ["overview", "access", "containers", "games", "dev"]

    def test_json_null_is_invalid(self, js):
        # JSON.parse("null") succeeds but yields nothing usable.
        out = self.parse(js, "null")
        assert out["state"] == "invalid"

    def test_json_array_is_invalid(self, js):
        out = self.parse(js, "[]")
        assert out["state"] == "invalid"

    def test_port_defaults_when_absent(self, js):
        out = self.parse(js, json.dumps({"serverName": "box"}))
        assert out["codeServerPort"] == 8443

    def test_out_of_range_port_falls_back(self, js):
        out = self.parse(js, json.dumps({"serverName": "box", "codeServerPort": 99999}))
        assert out["codeServerPort"] == 8443

    def test_zero_and_negative_ports_fall_back(self, js):
        for bad in (0, -1, -8443):
            out = self.parse(js, json.dumps({"serverName": "box", "codeServerPort": bad}))
            assert out["codeServerPort"] == 8443

    def test_non_numeric_port_falls_back(self, js):
        out = self.parse(js, json.dumps({"serverName": "box", "codeServerPort": "nope"}))
        assert out["codeServerPort"] == 8443

    def test_port_is_rounded(self, js):
        out = self.parse(js, json.dumps({"serverName": "box", "codeServerPort": 8443.7}))
        assert out["codeServerPort"] == 8444

    def test_numeric_string_port_is_accepted(self, js):
        out = self.parse(js, json.dumps({"serverName": "box", "codeServerPort": "9443"}))
        assert out["codeServerPort"] == 9443

    def test_unknown_tabs_are_dropped(self, js):
        out = self.parse(
            js, json.dumps({"serverName": "box", "tabOrder": ["bogus", "dev"]})
        )
        assert "bogus" not in out["tabOrder"]
        assert len(out["tabOrder"]) == 5

    def test_strings_are_trimmed(self, js):
        out = self.parse(
            js,
            json.dumps({"serverName": "  box  ", "serverRole": " NAS ", "preferredEditor": " code "}),
        )
        assert out["serverName"] == "box"
        assert out["serverRole"] == "NAS"
        assert out["preferredEditor"] == "code"


class TestTabDefs:
    """The tab strip's labels and icons, moved out of QML so they can be read."""

    def test_known_tabs_have_labels(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Config.tabDef("overview"), Config.tabDef("access"),'
            'Config.tabDef("containers"), Config.tabDef("games"),'
            'Config.tabDef("dev")]))'
        )
        assert [t["label"] for t in out] == [
            "Overview",
            "Access",
            "Containers",
            "Gaming",
            "Dev",
        ]

    def test_every_known_tab_has_an_icon(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Config.tabDef("overview"), Config.tabDef("access"),'
            'Config.tabDef("containers"), Config.tabDef("games"),'
            'Config.tabDef("dev")]))'
        )
        assert all(t["icon"].strip() for t in out)

    def test_unknown_tab_falls_back_to_its_id(self, js):
        out = js('console.log(JSON.stringify(Config.tabDef("bogus")))')
        assert out["id"] == "bogus"
        assert out["label"] == "bogus"
        assert out["icon"].strip()

    def test_default_order_matches_the_tab_table(self, js):
        # A tab added to DEFAULT_TAB_ORDER without a label would render blank.
        out = js(
            "console.log(JSON.stringify(Config.defaultTabOrder().map("
            "function (id) { return Config.tabDef(id).label; })))"
        )
        assert all(label and label != "bogus" for label in out)


class TestOrderedTabs:
    def test_saved_order_is_honoured(self, js):
        out = js(
            "console.log(JSON.stringify(Config.orderedTabs("
            '["dev","overview"]).map(function (t) { return t.id; })))'
        )
        assert out[:2] == ["dev", "overview"]

    def test_all_tabs_are_returned(self, js):
        out = js("console.log(JSON.stringify(Config.orderedTabs([])))")
        assert len(out) == 5
        assert sorted(t["id"] for t in out) == sorted(
            ["overview", "access", "containers", "games", "dev"]
        )

    def test_unknown_ids_never_reach_the_strip(self, js):
        out = js(
            "console.log(JSON.stringify(Config.orderedTabs("
            '["nope","games"]).map(function (t) { return t.id; })))'
        )
        assert "nope" not in out
        assert len(out) == 5

    def test_every_entry_is_renderable(self, js):
        out = js("console.log(JSON.stringify(Config.orderedTabs(null)))")
        assert all(t["label"] and t["icon"] for t in out)


class TestMoveTab:
    """Reordering the tab strip. Moves off either end are no-ops, not errors."""

    def move(self, js, order, index, delta):
        return js(
            "console.log(JSON.stringify(Config.moveTab(%s, %d, %d)))"
            % (json.dumps(order), index, delta)
        )

    def test_moving_right_swaps_with_the_next(self, js):
        assert self.move(js, ["a", "b", "c"], 0, 1) == ["b", "a", "c"]

    def test_moving_left_swaps_with_the_previous(self, js):
        assert self.move(js, ["a", "b", "c"], 2, -1) == ["a", "c", "b"]

    def test_moving_the_first_entry_up_does_nothing(self, js):
        assert self.move(js, ["a", "b", "c"], 0, -1) == ["a", "b", "c"]

    def test_moving_the_last_entry_down_does_nothing(self, js):
        assert self.move(js, ["a", "b", "c"], 2, 1) == ["a", "b", "c"]

    def test_index_out_of_range_is_ignored(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Config.moveTab(['a','b'], 5, 1), Config.moveTab(['a','b'], -1, 1)]))"
        )
        assert out == [["a", "b"], ["a", "b"]]

    def test_null_order_is_empty(self, js):
        assert self.move(js, None, 0, 1) == []

    def test_input_array_is_not_mutated(self, js):
        # The draft list is re-read on every move, so the source must survive.
        out = js(
            "var src = ['a','b','c'];"
            "var next = Config.moveTab(src, 0, 1);"
            "console.log(JSON.stringify([src, next]))"
        )
        assert out == [["a", "b", "c"], ["b", "a", "c"]]

    def test_result_is_always_the_same_length(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Config.moveTab(['a','b','c'], 0, 1).length,"
            "Config.moveTab(['a','b','c'], 0, -1).length]))"
        )
        assert out == [3, 3]


class TestWriteCommand:
    """Persisting config.json. A partial write would read back as corrupt.

    parseHubConfig treats unparseable JSON as `invalid`, which blanks every
    setting, so the write has to be all-or-nothing.
    """

    def cmd(self, js, path, payload):
        return js(
            "console.log(JSON.stringify(Config.writeCommand(%s, %s)))"
            % (json.dumps(path), json.dumps(payload))
        )

    def test_payload_is_its_own_argument(self, js):
        # Passed as argv, never interpolated into the shell string, so quotes
        # and $ in the JSON cannot be reinterpreted.
        out = self.cmd(js, "/tmp/c.json", '{"name":"a $b \\"c\\""}')
        assert out[4] == '{"name":"a $b \\"c\\""}'

    def test_write_goes_through_a_temp_file_and_rename(self, js):
        out = self.cmd(js, "/tmp/c.json", "{}")
        script = out[2]
        assert "mv -f" in script
        assert out[6].startswith("/tmp/c.json") and ".tmp" in out[6]

    def test_temp_file_is_a_sibling_of_the_target(self, js):
        # A temp file on another filesystem cannot be renamed atomically.
        out = self.cmd(js, "/home/u/.config/x/config.json", "{}")
        tmp = out[6]
        assert tmp.rsplit("/", 1)[0] == "/home/u/.config/x"

    def test_round_trip_through_a_real_shell(self, js, tmp_path):
        target = tmp_path / "config.json"
        out = self.cmd(js, str(target), '{"serverName":"Vember OS"}')
        subprocess.run(out, check=True)
        assert json.loads(target.read_text())["serverName"] == "Vember OS"
        # No temp file is left behind on success.
        assert not list(tmp_path.glob("*.tmp*"))

    def test_overwrite_replaces_wholesale(self, js, tmp_path):
        target = tmp_path / "config.json"
        target.write_text('{"old": "content that is longer"}')
        out = self.cmd(js, str(target), '{"new":1}')
        subprocess.run(out, check=True)
        assert json.loads(target.read_text()) == {"new": 1}


class TestParseManifest:
    """The manifest parser must not be the hub-config parser.

    The refactor once fed manifest.json to parseHubConfig, which read it as a
    config with no serverName (state "wizard"), opened the first-run wizard and
    blanked the server name in a race with the real config load. This parser
    only ever returns the manifest object or null.
    """

    def parse(self, js, raw):
        return js(
            "console.log(JSON.stringify(Config.parseManifest(%s)))"
            % json.dumps(raw)
        )

    def test_missing_manifest_is_null(self, js):
        assert self.parse(js, "") is None

    def test_unreadable_json_is_null(self, js):
        assert self.parse(js, "{not json") is None

    def test_array_is_not_a_manifest(self, js):
        assert self.parse(js, "[]") is None

    def test_null_is_not_a_manifest(self, js):
        assert self.parse(js, "null") is None

    def test_manifest_object_round_trips(self, js):
        out = self.parse(js, json.dumps({"version": "0.6.1", "build": 77}))
        assert out == {"version": "0.6.1", "build": 77}

    def test_real_manifest_parses(self, js):
        # Read the repo's own manifest so a broken file fails here, not in the
        # shell. Build must be an int for the version guard to hold.
        import pathlib

        raw = (pathlib.Path(__file__).resolve().parents[1] / "manifest.json").read_text()
        out = self.parse(js, raw)
        assert isinstance(out, dict)
        assert isinstance(out.get("version"), str) and out["version"]
        assert isinstance(out.get("build"), int)


class TestConfigRead:
    """A config read must tell "no file" apart from "could not read".

    The old command was `[ -f "$1" ] && cat "$1"`, so a read failure produced
    empty output, which parsed as "empty" and opened the first-run wizard. At
    startup configReady is false, so that wizard has no Cancel button, and Save
    would overwrite a good config with the hostname.
    """

    @staticmethod
    def _command(js, path):
        return js("console.log(JSON.stringify(Config.readCommand(%s)))" % json.dumps(str(path)))

    @staticmethod
    def _outcome(js, raw):
        return js("console.log(JSON.stringify(Config.readOutcome(%s)))" % json.dumps(raw))

    def test_outcome_of_the_missing_marker(self, js):
        assert self._outcome(js, "VEMBER-CONFIG-MISSING") == "missing"

    def test_outcome_of_the_unreadable_marker(self, js):
        assert self._outcome(js, "VEMBER-CONFIG-UNREADABLE") == "unreadable"

    def test_outcome_of_real_content(self, js):
        assert self._outcome(js, '{"serverName":"Vember OS"}') == "content"

    def test_outcome_of_an_empty_file(self, js):
        # A zero-byte file is content (empty), not a missing file; the parser
        # still treats it as first use.
        assert self._outcome(js, "") == "content"

    def test_a_missing_file_is_reported_missing(self, js, tmp_path):
        cmd = self._command(js, tmp_path / "absent.json")
        proc = subprocess.run(cmd, capture_output=True, text=True)
        assert proc.returncode == 0, proc.stderr
        assert proc.stdout == "VEMBER-CONFIG-MISSING"

    def test_an_unreadable_file_is_reported_unreadable(self, js, tmp_path):
        import os

        if hasattr(os, "geteuid") and os.geteuid() == 0:
            import pytest

            pytest.skip("running as root: file permissions are not enforced")
        path = tmp_path / "config.json"
        path.write_text('{"serverName":"Vember OS"}')
        path.chmod(0o000)
        try:
            cmd = self._command(js, path)
            proc = subprocess.run(cmd, capture_output=True, text=True)
        finally:
            path.chmod(0o644)
        assert proc.returncode == 0, proc.stderr
        assert proc.stdout == "VEMBER-CONFIG-UNREADABLE"

    def test_a_readable_file_returns_its_content(self, js, tmp_path):
        path = tmp_path / "config.json"
        path.write_text('{"serverName":"Vember OS"}')
        cmd = self._command(js, path)
        proc = subprocess.run(cmd, capture_output=True, text=True)
        assert proc.returncode == 0, proc.stderr
        assert proc.stdout == '{"serverName":"Vember OS"}'
        assert self._outcome(js, proc.stdout) == "content"
