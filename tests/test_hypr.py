"""Tests for model/Hypr.mjs: window focus against the Lua dispatcher.

Hyprland 0.56 turned `hyprctl dispatch` into a Lua entry point, so the old
`hyprctl dispatch focuswindow 'class:^name$'` argument is a syntax error. The
generated script has to use a dispatcher object, and it has to read success
from the output because a miss still exits 0.
"""

import subprocess


class TestFocusScript:
    def test_empty_selectors_is_a_no_op(self, js):
        assert js('console.log(JSON.stringify(Hypr.focusScript([])))') == "true"

    def test_uses_the_dispatcher_object_form(self, js):
        script = js('console.log(JSON.stringify(Hypr.focusScript(["class:foo"])))')
        assert "hl.dsp.focus" in script
        assert 'window="%s"' in script
        assert "focus_win 'class:foo'" in script

    def test_reads_success_from_output_not_exit_code(self, js):
        # A miss prints "window not found" and still exits 0, so an || chain
        # would stop on the first selector and never try the fallbacks.
        script = js('console.log(JSON.stringify(Hypr.focusScript(["class:foo"])))')
        assert 'case "$out" in *ok*)' in script

    def test_keeps_the_legacy_form_as_a_fallback(self, js):
        script = js('console.log(JSON.stringify(Hypr.focusScript(["class:foo"])))')
        assert "focuswindow" in script

    def test_missing_hyprctl_is_not_an_error(self, js):
        script = js('console.log(JSON.stringify(Hypr.focusScript(["class:foo"])))')
        assert "command -v hyprctl" in script
        # The whole snippet must succeed even when hyprctl is absent. The
        # launcher script's exit status is the focus snippet's, and the panel
        # used to read a non-zero exit as "the terminal never opened" and stop
        # tracking a real install.
        assert script.rstrip().endswith("|| true")
        result = subprocess.run(
            ["/bin/sh", "-c", script],
            capture_output=True,
            text=True,
            env={"PATH": "/nonexistent"},
        )
        assert result.returncode == 0, result.stderr

    def test_script_is_valid_shell(self, js):
        script = js('console.log(JSON.stringify(Hypr.focusScript(["class:foo"])))')
        result = subprocess.run(
            ["sh", "-n"], input=script, capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr

    def test_selectors_are_tried_in_order(self, js):
        script = js(
            'console.log(JSON.stringify(Hypr.focusScript(["class:a", "title:b"])))'
        )
        assert script.index("focus_win 'class:a'") < script.index("focus_win 'title:b'")


class TestFocusByClassScript:
    def test_class_then_anchored_title_then_bare_title(self, js):
        script = js(
            'console.log(JSON.stringify(Hypr.focusByClassScript("vember-install", "Vember Install: Steam")))'
        )
        class_at = script.index("focus_win 'class:vember-install'")
        anchored_at = script.index("focus_win 'title:^(Vember Install: Steam)$'")
        bare_at = script.index("focus_win 'title:Vember Install: Steam'")
        assert class_at < anchored_at < bare_at

    def test_missing_title_keeps_only_the_class(self, js):
        script = js(
            'console.log(JSON.stringify(Hypr.focusByClassScript("vember-install", "")))'
        )
        assert "focus_win 'class:vember-install'" in script
        assert "title:" not in script

    def test_empty_class_and_title_is_a_no_op(self, js):
        assert js('console.log(JSON.stringify(Hypr.focusByClassScript("", "")))') == "true"

    def test_single_quotes_in_a_title_are_escaped(self, js):
        script = js(
            'console.log(JSON.stringify(Hypr.focusByClassScript("c", "Elena\'s Install")))'
        )
        result = subprocess.run(
            ["sh", "-n"], input=script, capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr
