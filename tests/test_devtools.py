"""Tests for model/DevTools.mjs: tool detection, repo scanning, Code Server."""

import subprocess


class TestToolChecks:
    def test_installed_tool_is_parsed(self, js):
        out = js(
            'console.log(JSON.stringify(DevTools.parseChecks('
            '"uv\\tyes\\t/usr/bin/uv\\tuv 0.13.9\\n")))'
        )
        assert out == [
            {
                "id": "uv",
                "installed": True,
                "path": "/usr/bin/uv",
                "version": "uv 0.13.9",
            }
        ]

    def test_missing_tool_is_parsed(self, js):
        out = js('console.log(JSON.stringify(DevTools.parseChecks("python\\tno\\t\\t\\n")))')
        assert out == [{"id": "python", "installed": False, "path": "", "version": ""}]

    def test_blank_lines_are_dropped(self, js):
        assert js('console.log(JSON.stringify(DevTools.parseChecks("\\n \\n")))') == []

    def test_check_script_is_valid_sh(self, js):
        cmd = js("console.log(JSON.stringify(DevTools.checkCommand()))")
        assert cmd[0] == "sh"
        result = subprocess.run(
            ["sh", "-n"], input=cmd[2], capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr

    def test_check_script_searches_per_user_bin_dirs(self, js):
        # The panel does not inherit a login shell PATH, so these must be added
        # explicitly or uv/gh installed under ~ look absent.
        cmd = js("console.log(JSON.stringify(DevTools.checkCommand()))")
        assert "$HOME/.local/bin" in cmd[2]
        assert "$HOME/.cargo/bin" in cmd[2]
        assert "$HOME/.local/share/pnpm" in cmd[2]

    def test_per_user_dirs_are_appended_not_prepended(self, js):
        cmd = js("console.log(JSON.stringify(DevTools.checkCommand()))")
        script = cmd[2]
        # Prepending made a stale ~/.local/bin/uv (0.13.5) shadow the 0.13.9
        # that mise puts on PATH, so the panel reported the wrong version.
        assert script.index("$PATH") < script.index("$HOME/.local/bin"), (
            "per-user bin dirs must be appended to PATH, not prepended"
        )

    def test_version_comes_from_the_resolved_binary(self, js):
        cmd = js("console.log(JSON.stringify(DevTools.checkCommand()))")
        script = cmd[2]
        assert '"$p" --version' in script, (
            "the version must be read from the binary found by command -v"
        )
        for name in ("uv", "python3", "gh", "zed", "zeditor", "code", "code-oss"):
            assert name + " --version" not in script, (
                "a bare " + name + " --version could resolve to a different "
                "binary than the path shown in the panel"
            )

    def test_labels_are_human_readable(self, js):
        out = js(
            "console.log(JSON.stringify("
            '["uv","python","gh","zed","vscode","other"].map(DevTools.label)))'
        )
        assert out == ["uv", "Python", "GitHub CLI", "Zed", "VS Code", "other"]

    def test_empty_label_is_empty(self, js):
        assert js('console.log(JSON.stringify(DevTools.label("")))') == ""


class TestRepoScan:
    def test_paths_become_named_rows(self, js):
        out = js(
            'console.log(JSON.stringify(DevTools.parseRepos("/h/Projects/alpha\\n/h/Projects/beta")))'
        )
        assert out == [
            {"path": "/h/Projects/alpha", "name": "alpha"},
            {"path": "/h/Projects/beta", "name": "beta"},
        ]

    def test_blank_lines_are_dropped(self, js):
        assert js('console.log(JSON.stringify(DevTools.parseRepos("\\n\\n")))') == []

    def test_scan_command_receives_home_dir(self, js):
        cmd = js('console.log(JSON.stringify(DevTools.reposScanCommand("/home/x")))')
        assert cmd[0] == "sh"
        assert cmd[-1] == "/home/x"
        assert "Projects" in cmd[2]

    def test_detail_command_is_valid_sh(self, js):
        cmd = js('console.log(JSON.stringify(DevTools.repoDetailCommand("/tmp/repo")))')
        result = subprocess.run(
            ["sh", "-n"], input=cmd[2], capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr


class TestRepoDetail:
    def test_all_fields_are_parsed(self, js):
        out = js(
            "console.log(JSON.stringify(DevTools.parseRepoDetail("
            '"SIZE\\t1.2M\\nMTIME\\t2026-01-01\\nBRANCH\\tmain\\nDIRTY\\tclean\\n'
            'REMOTE\\tgit@x:y\\nLAST\\t2026-01-01 msg")))'
        )
        assert out["size"] == "1.2M"
        assert out["branch"] == "main"
        assert out["dirty"] == "clean"
        assert out["remote"] == "git@x:y"
        assert out["last"] == "2026-01-01 msg"
        assert out["error"] == ""

    def test_error_field_is_parsed(self, js):
        out = js('console.log(JSON.stringify(DevTools.parseRepoDetail("ERR\\tNot a directory")))')
        assert out["error"] == "Not a directory"

    def test_unknown_keys_are_ignored(self, js):
        out = js('console.log(JSON.stringify(DevTools.parseRepoDetail("WHAT\\tx")))')
        assert out["size"] == "" and out["error"] == ""

    def test_lines_without_tab_are_ignored(self, js):
        out = js('console.log(JSON.stringify(DevTools.parseRepoDetail("garbage\\nBRANCH\\tmain")))')
        assert out["branch"] == "main"


class TestCodeServer:
    def test_container_name_is_stable(self, js):
        assert js("console.log(JSON.stringify(DevTools.codeServerContainer()))") == "vember-code-server"

    def test_ps_command_filters_on_exact_name(self, js):
        cmd = js("console.log(JSON.stringify(DevTools.codeServerPsCommand()))")
        assert "^/vember-code-server$" in cmd[2]

    def test_running_container_is_parsed(self, js):
        out = js(
            'console.log(JSON.stringify(DevTools.parseCodeServerStatus('
            '"vember-code-server\\trunning\\tUp 3 hours\\tlscr.io/x/code-server:latest")))'
        )
        assert out == {
            "present": True,
            "running": True,
            "state": "running",
            "status": "Up 3 hours",
            "image": "lscr.io/x/code-server:latest",
        }

    def test_stopped_container_is_not_running(self, js):
        out = js(
            'console.log(JSON.stringify(DevTools.parseCodeServerStatus('
            '"vember-code-server\\texited\\tExited (0) 1 day ago\\timg")))'
        )
        assert out["present"] is True
        assert out["running"] is False

    def test_absent_container_reports_not_found(self, js):
        out = js('console.log(JSON.stringify(DevTools.parseCodeServerStatus("")))')
        assert out == {
            "present": False,
            "running": False,
            "state": "not found",
            "status": "",
            "image": "",
        }


class TestCodeServerNaming:
    """The container and its config directory share one name.

    Panel.qml builds the setup script, the docker run arguments and the status
    query from these helpers. If the two ever disagreed, setup would write
    settings into a directory the container never mounts.
    """

    def test_container_name(self, js):
        assert js("console.log(JSON.stringify(DevTools.codeServerContainer()))") == (
            "vember-code-server"
        )

    def test_config_dir_matches_the_container_name(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "DevTools.codeServerConfigDir(), DevTools.codeServerContainer()]))"
        )
        directory, name = out
        assert directory == "$HOME/.config/" + name

    def test_status_query_uses_the_same_name(self, js):
        out = js("console.log(JSON.stringify(DevTools.codeServerPsCommand()))")
        name = js("console.log(JSON.stringify(DevTools.codeServerContainer()))")
        assert name in out[2]

    def test_status_query_is_an_anchored_exact_match(self, js):
        # A prefix match would also report a container called
        # vember-code-server-2 as the one this plugin manages.
        out = js("console.log(JSON.stringify(DevTools.codeServerPsCommand()))")
        name = js("console.log(JSON.stringify(DevTools.codeServerContainer()))")
        assert "name=^/" + name + "$" in out[2]
