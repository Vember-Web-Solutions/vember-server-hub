"""Tests for model/Shell.mjs: text, quoting and formatting helpers."""

import subprocess


class TestTrim:
    def test_strips_surrounding_whitespace(self, js):
        assert js('console.log(JSON.stringify(Shell.trim("  hi  ")))') == "hi"

    def test_handles_null_and_undefined(self, js):
        out = js(
            "console.log(JSON.stringify([Shell.trim(null), Shell.trim(undefined)]))"
        )
        assert out == ["", ""]

    def test_numbers_become_strings(self, js):
        assert js("console.log(JSON.stringify(Shell.trim(42)))") == "42"


class TestLines:
    def test_splits_and_normalises_crlf(self, js):
        out = js('console.log(JSON.stringify(Shell.lines("a\\r\\nb")))')
        assert out == ["a", "b"]

    def test_empty_input_yields_empty_list(self, js):
        assert js('console.log(JSON.stringify(Shell.lines("   ")))') == []

    def test_non_empty_lines_trims_and_drops_blanks(self, js):
        out = js('console.log(JSON.stringify(Shell.nonEmptyLines(" a \\n\\n b \\n")))')
        assert out == ["a", "b"]


class TestAnsi:
    def test_strips_colour_codes(self, js):
        out = js(
            'console.log(JSON.stringify(Shell.stripAnsi("\\u001b[31mred\\u001b[0m x")))'
        )
        assert out == "red x"

    def test_strips_osc_sequences(self, js):
        out = js(
            'console.log(JSON.stringify(Shell.stripAnsi("\\u001b]0;title\\u0007done")))'
        )
        assert out == "done"


class TestQuote:
    def test_single_quotes_are_escaped_for_sh(self, js):
        quoted = js(
            "console.log(JSON.stringify(Shell.quote(\"it's a 'test'\")))"
        )
        result = subprocess.run(
            ["sh", "-c", "printf '%s' " + quoted], capture_output=True, text=True
        )
        assert result.returncode == 0
        assert result.stdout == "it's a 'test'"

    def test_quotes_spaces_and_globs(self, js):
        quoted = js('console.log(JSON.stringify(Shell.quote("a b * c")))')
        result = subprocess.run(
            ["sh", "-c", "printf '%s' " + quoted], capture_output=True, text=True
        )
        assert result.stdout == "a b * c"


class TestFormatting:
    def test_safe_name_keeps_simple_names(self, js):
        assert js('console.log(JSON.stringify(Shell.safeName(" My Server ")))') == "My Server"

    def test_status_label_picks_branch(self, js):
        out = js(
            'console.log(JSON.stringify([Shell.statusLabel(true,"Up","Down"),'
            'Shell.statusLabel(false,"Up","Down")]))'
        )
        assert out == ["Up", "Down"]

    def test_human_bytes_scales_units(self, js):
        out = js(
            "console.log(JSON.stringify([Shell.humanBytes(0), Shell.humanBytes(1536),"
            "Shell.humanBytes(5*1024*1024*1024)]))"
        )
        assert out == ["0 B", "2 KiB", "5.0 GiB"]

    def test_human_bytes_rejects_junk(self, js):
        assert js("console.log(JSON.stringify(Shell.humanBytes('nope')))") == "0 B"


class TestKeyValueLines:
    def test_parses_equals_and_colon(self, js):
        out = js(
            'console.log(JSON.stringify(Shell.parseKeyValueLines("A=1\\nB: 2\\nbad\\n")))'
        )
        assert out == {"A": "1", "B": "2"}

    def test_ignores_blank_lines(self, js):
        out = js(
            'console.log(JSON.stringify(Shell.parseKeyValueLines("\\nA=1\\n\\n")))'
        )
        assert out == {"A": "1"}
