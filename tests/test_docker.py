"""Tests for model/Docker.mjs: command construction and `docker ps` parsing."""

import subprocess


class TestCommands:
    def test_ps_lists_all_containers_with_tabs(self, js):
        out = js("console.log(JSON.stringify(Docker.psCommand()))")
        assert out[0] == "docker"
        assert out[1] == "ps"
        assert "-a" in out
        assert "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}" in out

    def test_action_command_passes_action_and_name(self, js):
        out = js('console.log(JSON.stringify(Docker.actionCommand("stop", "web")))')
        assert out == ["docker", "stop", "web"]

    def test_pull_command_names_the_image(self, js):
        out = js('console.log(JSON.stringify(Docker.pullCommand("nginx:latest")))')
        assert out == ["docker", "pull", "nginx:latest"]

    def test_prune_is_forced_container_prune(self, js):
        # `-f` matters: the panel already asks for confirmation, so the
        # command must never stop to prompt inside the terminal.
        out = js("console.log(JSON.stringify(Docker.pruneCommand()))")
        assert out == ["docker", "container", "prune", "-f"]


class TestParsePs:
    def test_running_container(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.parsePs("
            '"web\\tnginx:latest\\trunning\\tUp 2 hours")))'
        )
        assert out == [
            {
                "name": "web",
                "image": "nginx:latest",
                "state": "running",
                "status": "Up 2 hours",
                "running": True,
            }
        ]

    def test_stopped_container_is_not_running(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.parsePs("
            '"db\\tpostgres:16\\texited\\tExited (0) 3 days ago")))'
        )
        assert out[0]["state"] == "exited"
        assert out[0]["running"] is False
        assert out[0]["status"] == "Exited (0) 3 days ago"

    def test_blank_lines_are_dropped(self, js):
        out = js('console.log(JSON.stringify(Docker.parsePs("\\n\\n  \\n")))')
        assert out == []

    def test_tab_only_rows_are_dropped(self, js):
        # nonEmptyLines trims each line, so a row of bare tabs is empty.
        out = js('console.log(JSON.stringify(Docker.parsePs("\\t\\t\\t\\n")))')
        assert out == []

    def test_surrounding_whitespace_is_trimmed(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.parsePs("
            '"  web  \\t nginx \\t running \\t Up 1 min  ")))'
        )
        assert out[0]["name"] == "web"
        assert out[0]["image"] == "nginx"
        assert out[0]["status"] == "Up 1 min"

    def test_state_is_lowercased(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.parsePs("
            '"web\\tnginx\\tRUNNING\\tUp 1 minute")))'
        )
        assert out[0]["state"] == "running"
        assert out[0]["running"] is True

    def test_status_falls_back_when_missing(self, js):
        out = js('console.log(JSON.stringify(Docker.parsePs("web\\tnginx\\trunning")))')
        assert out[0]["status"] == "running"

    def test_missing_state_defaults_to_unknown(self, js):
        out = js('console.log(JSON.stringify(Docker.parsePs("web\\tnginx")))')
        assert out[0]["state"] == "unknown"
        assert out[0]["running"] is False
