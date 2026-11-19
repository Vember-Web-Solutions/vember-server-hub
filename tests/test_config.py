"""Tests for model/Config.mjs: tab ordering that survives config drift."""

import json


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
