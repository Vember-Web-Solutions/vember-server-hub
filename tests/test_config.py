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
