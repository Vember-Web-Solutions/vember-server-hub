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


class TestWatchdogVerdict:
    """The install watchdog's branch decision, pulled out of QML to be testable.

    The bug this guards: a terminal closed after the first line of output left
    the panel stuck on "running". The verdict for a dead pid must be "dead"
    regardless of whether the log has content, and "never-started" only applies
    when there is no output to tail.
    """

    def _verdict(self, js, code, has_output):
        return js(
            "console.log(JSON.stringify(InstallLog.watchdogVerdict(%d, %s)))"
            % (code, "true" if has_output else "false")
        )

    def test_alive_is_alive_with_or_without_output(self, js):
        assert self._verdict(js, 0, False) == "alive"
        assert self._verdict(js, 0, True) == "alive"

    def test_dead_pid_is_dead_even_with_output(self, js):
        # This is the regression: a dead terminal that produced output must
        # still be reported dead, not ignored because the log is non-empty.
        assert self._verdict(js, 1, False) == "dead"
        assert self._verdict(js, 1, True) == "dead"

    def test_missing_lock_without_output_never_started(self, js):
        assert self._verdict(js, 2, False) == "never-started"

    def test_missing_lock_with_output_is_teardown(self, js):
        # The wrapper removes the lock after writing the exit marker; `tail`
        # is about to finish, so the watchdog should do nothing.
        assert self._verdict(js, 2, True) == "teardown"

    def test_lock_without_pid_waits(self, js):
        assert self._verdict(js, 3, False) == "wait"
        assert self._verdict(js, 3, True) == "wait"

    def test_unknown_code_waits(self, js):
        assert self._verdict(js, 7, False) == "wait"


class TestLockCheckCommand:
    """The lock check is real shell; run it against real lock files.

    Exit codes are the watchdog's vocabulary: 0 alive, 1 dead, 2 no lock,
    3 pid not written yet. Both the install watchdog and the Omarchy update
    watchdog depend on them, and the two lock files put the pid on different
    lines, so the pid line is checked explicitly.
    """

    @staticmethod
    def _dead_pid():
        p = subprocess.Popen(["sh", "-c", "exit 0"])
        p.wait()
        return p.pid

    def _run(self, js, lock, pid_line):
        import json

        argv = js(
            "console.log(JSON.stringify(InstallLog.lockCheckCommand(%s, %d)))"
            % (json.dumps(str(lock)), pid_line)
        )
        return subprocess.run(argv).returncode

    def test_alive_process_reports_zero(self, js, tmp_path):
        import os

        lock = tmp_path / "install.lock"
        lock.write_text("abc123\n%d\n" % os.getpid())
        assert self._run(js, lock, 2) == 0

    def test_dead_pid_reports_one(self, js, tmp_path):
        lock = tmp_path / "install.lock"
        lock.write_text("abc123\n%d\n" % self._dead_pid())
        assert self._run(js, lock, 2) == 1

    def test_missing_lock_reports_two(self, js, tmp_path):
        assert self._run(js, tmp_path / "nope.lock", 2) == 2

    def test_lock_without_pid_line_reports_three(self, js, tmp_path):
        lock = tmp_path / "install.lock"
        lock.write_text("abc123\n")
        assert self._run(js, lock, 2) == 3

    def test_pid_line_is_honoured(self, js, tmp_path):
        import os

        # The Omarchy update lock stores only the pid, on line 1.
        lock = tmp_path / "omarchy-update.lock"
        lock.write_text("%d\n" % os.getpid())
        assert self._run(js, lock, 1) == 0
        # Reading line 2 of the same file finds nothing.
        assert self._run(js, lock, 2) == 3


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


class TestInteractivePrompts:
    """The original bug: an install that asked for a sudo password or a y/n
    appeared to hang.

    The payload has to keep the terminal's pty as its stdin. This runs the real
    generated script against a stub xdg-terminal-exec that allocates a pty and
    types an answer, the way a terminal emulator does.
    """

    @staticmethod
    def _stub(bindir):
        stub = bindir / "xdg-terminal-exec"
        stub.write_text(
            """#!/usr/bin/env bash
# Drop --flags, then run the command on a pty fed with a typed answer.
while [ $# -gt 0 ]; do case "$1" in --*) shift ;; *) break ;; esac; done
cmd="$(printf '%q' "$1")"; shift
while [ $# -gt 0 ]; do cmd="$cmd $(printf '%q' "$1")"; shift; done
printf 'yes\\n' | script -qec "$cmd" /dev/null
"""
        )
        stub.chmod(0o755)

    def test_payload_can_read_a_typed_answer(self, js, tmp_path):
        import json
        import os
        import shutil
        import time

        if shutil.which("script") is None:
            import pytest

            pytest.skip("script(1) is not installed")

        bindir = tmp_path / "bin"
        bindir.mkdir()
        self._stub(bindir)

        log = tmp_path / "install.log"
        title = tmp_path / "title.txt"
        lock = tmp_path / "install.lock"

        payload = "printf 'continue? '; read -r answer; echo \"got:$answer\"; exit 7"
        script = js(
            "console.log(JSON.stringify(InstallLog.terminalScript('Smoke', %s, %s, %s, %s, 'smoke')))"
            % (
                json.dumps(payload),
                json.dumps(str(log)),
                json.dumps(str(title)),
                json.dumps(str(lock)),
            )
        )

        env = dict(os.environ, PATH="%s:%s" % (bindir, os.environ["PATH"]))
        subprocess.run(
            ["bash", "-c", script], env=env, capture_output=True, timeout=60
        )

        # The launcher backgrounds the terminal, so wait for the payload to end.
        deadline = time.time() + 30
        while time.time() < deadline:
            if log.exists() and "[vember-install-exit:" in log.read_text():
                break
            time.sleep(0.2)

        text = log.read_text()
        assert "got:yes" in text, "payload never received the typed answer:\n" + text
        assert "[vember-install-exit:7]" in text
        assert not lock.exists(), "lock file outlived the install"
