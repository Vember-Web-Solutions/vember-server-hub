"""Tests for model/InstallLog.mjs: log paths, the terminal wrapper, log parsing."""

import subprocess


class TestPaths:
    def test_cache_dir_lives_under_home(self, js):
        out = js('console.log(JSON.stringify(InstallLog.cacheDir("/home/x")))')
        assert out == "/home/x/.cache/vember-server-hub"

    def test_each_artifact_has_its_own_file(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'InstallLog.logPath("/h"), InstallLog.titlePath("/h"),'
            'InstallLog.lockPath("/h"), InstallLog.omarchyLockPath("/h")]))'
        )
        assert out == [
            "/h/.cache/vember-server-hub/install.log",
            "/h/.cache/vember-server-hub/install-title.txt",
            "/h/.cache/vember-server-hub/install.lock",
            "/h/.cache/vember-server-hub/omarchy-update.lock",
        ]

    def test_paths_are_distinct(self, js):
        out = js(
            "console.log(JSON.stringify(new Set(["
            'InstallLog.logPath("/h"), InstallLog.titlePath("/h"),'
            'InstallLog.lockPath("/h"), InstallLog.omarchyLockPath("/h")]).size))'
        )
        assert out == 4


class TestParse:
    def test_plain_output_is_unfinished(self, js):
        out = js('console.log(JSON.stringify(InstallLog.parse("one\\ntwo")))')
        assert out == {"text": "one\ntwo", "finished": False, "exitCode": None}

    def test_exit_marker_finishes_and_reports_code(self, js):
        out = js(
            'console.log(JSON.stringify(InstallLog.parse("work\\n[vember-install-exit:0]")))'
        )
        assert out["finished"] is True
        assert out["exitCode"] == 0
        assert out["text"] == "work"

    def test_nonzero_exit_is_kept(self, js):
        out = js(
            'console.log(JSON.stringify(InstallLog.parse("boom\\n[vember-install-exit:127]")))'
        )
        assert out["exitCode"] == 127

    def test_empty_exit_marker_reports_null_code(self, js):
        # The wrapper emits an empty code when PIPESTATUS is unavailable.
        out = js('console.log(JSON.stringify(InstallLog.parse("[vember-install-exit:]")))')
        assert out["finished"] is True
        assert out["exitCode"] is None

    def test_marker_line_is_not_shown_in_the_log(self, js):
        out = js(
            'console.log(JSON.stringify(InstallLog.parse("a\\n[vember-install-exit:1]\\nb")))'
        )
        assert "vember-install-exit" not in out["text"]
        assert out["text"] == "a\nb"

    def test_ansi_colour_is_stripped(self, js):
        out = js(
            'console.log(JSON.stringify(InstallLog.parse("\\u001b[32mok\\u001b[0m")))'
        )
        assert out["text"] == "ok"

    def test_leading_and_trailing_blank_lines_are_trimmed(self, js):
        out = js('console.log(JSON.stringify(InstallLog.parse("\\n\\nhi\\n\\n")))')
        assert out["text"] == "hi"

    def test_limit_keeps_the_tail(self, js):
        out = js('console.log(JSON.stringify(InstallLog.parse("abcdefghij", 4)))')
        assert out["text"] == "ghij"

    def test_limit_zero_keeps_everything(self, js):
        out = js('console.log(JSON.stringify(InstallLog.parse("abcdefghij", 0)))')
        assert out["text"] == "abcdefghij"


class TestTerminalScript:
    ARGS = (
        '"Install Steam", "echo hi", "/h/.cache/hub/install.log",'
        '"/h/.cache/hub/install-title.txt", "/h/.cache/hub/install.lock", "abc123"'
    )

    def test_script_is_valid_bash(self, js):
        script = js("console.log(JSON.stringify(InstallLog.terminalScript(%s)))" % self.ARGS)
        result = subprocess.run(
            ["bash", "-n"], input=script, capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr

    def test_script_opens_the_install_terminal(self, js):
        script = js("console.log(JSON.stringify(InstallLog.terminalScript(%s)))" % self.ARGS)
        assert "xdg-terminal-exec" in script
        assert "--app-id=vember-install" in script
        assert "class:^(vember-install)$" in script

    def test_script_records_lock_with_id_and_pid(self, js):
        # The lock writer sits inside the single-quoted payload handed to
        # `bash -lc`, so it appears escaped in the outer script.
        script = js("console.log(JSON.stringify(InstallLog.terminalScript(%s)))" % self.ARGS)
        assert "abc123" in script
        assert "$$" in script
        assert script.count("install.lock") >= 2

    def test_script_writes_exit_marker_and_tees_log(self, js):
        script = js("console.log(JSON.stringify(InstallLog.terminalScript(%s)))" % self.ARGS)
        assert "[vember-install-exit:${code}]" in script
        assert "( echo hi ) 2>&1 | tee" in script
        assert "code=${PIPESTATUS[0]}" in script

    def test_script_truncates_the_log_before_running(self, js):
        script = js("console.log(JSON.stringify(InstallLog.terminalScript(%s)))" % self.ARGS)
        assert ": > '/h/.cache/hub/install.log'" in script

    def test_missing_terminal_is_reported_in_the_log(self, js):
        script = js("console.log(JSON.stringify(InstallLog.terminalScript(%s)))" % self.ARGS)
        assert "xdg-terminal-exec not found" in script
        assert "[vember-install-exit:127]" in script

    def test_no_lock_path_omits_lock_lines(self, js):
        script = js(
            'console.log(JSON.stringify(InstallLog.terminalScript('
            '"T", "echo hi", "/h/install.log", "/h/title.txt", "", "abc")))'
        )
        assert "install.lock" not in script

    def test_quotes_in_title_cannot_escape(self, js):
        script = js(
            "console.log(JSON.stringify(InstallLog.terminalScript("
            "\"it's $(rm -rf /)\", \"echo hi\", \"/h/l.log\", \"/h/t.txt\", \"\", \"id\")))"
        )
        result = subprocess.run(
            ["bash", "-n"], input=script, capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
