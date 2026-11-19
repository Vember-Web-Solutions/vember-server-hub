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


    def test_human_bytes_scales_units(self, js):
        out = js(
            "console.log(JSON.stringify([Shell.humanBytes(0), Shell.humanBytes(1536),"
            "Shell.humanBytes(5*1024*1024*1024)]))"
        )
        assert out == ["0 B", "2 KiB", "5.0 GiB"]

    def test_human_bytes_rejects_junk(self, js):
        assert js("console.log(JSON.stringify(Shell.humanBytes('nope')))") == "0 B"



class TestFailureMessage:
    """Failure lines carry the command's own reason, not just an exit code.

    "Docker start failed for nginx (code 1)" leaves the user with nothing to
    act on; the daemon usually says why.
    """

    def test_no_stderr_keeps_the_original_phrasing(self, js):
        out = js(
            "console.log(JSON.stringify("
            "Shell.failureMessage('Docker start failed for nginx', 1, '')))"
        )
        assert out == "Docker start failed for nginx (code 1)."

    def test_stderr_is_appended(self, js):
        out = js(
            "console.log(JSON.stringify(Shell.failureMessage("
            "'Docker start failed for nginx', 1,"
            "'Error response from daemon: port is already allocated')))"
        )
        assert out == (
            "Docker start failed for nginx (code 1): "
            "Error response from daemon: port is already allocated."
        )

    def test_only_the_first_meaningful_line_is_used(self, js):
        # Multi-line stderr would otherwise stretch the status line.
        out = js(
            "console.log(JSON.stringify(Shell.failureMessage("
            "'Install failed', 2, '\\n\\n  first reason  \\nsecond reason\\n')))"
        )
        assert out == "Install failed (code 2): first reason."

    def test_missing_stderr_is_tolerated(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Shell.failureMessage('Thing failed', 3, null),"
            "Shell.failureMessage('Thing failed', 3, undefined)]))"
        )
        assert out == ["Thing failed (code 3).", "Thing failed (code 3)."]

    def test_whitespace_only_stderr_counts_as_empty(self, js):
        out = js(
            "console.log(JSON.stringify(Shell.failureMessage('Thing failed', 1, '   \\n  ')))"
        )
        assert out == "Thing failed (code 1)."

    def test_zero_exit_code_is_reported_as_given(self, js):
        # Callers only use this on failure, but the code must not be swallowed.
        out = js("console.log(JSON.stringify(Shell.failureMessage('Thing failed', 0, '')))")
        assert out == "Thing failed (code 0)."
