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


class TestParseSize:
    """Sizes appear in `docker pull` output as 12.3MB / 1.5GiB / 900B."""

    def test_byte_suffixes_scale(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Docker.parseSize('1B'), Docker.parseSize('1kB'),"
            "Docker.parseSize('1MB'), Docker.parseSize('1GB')]))"
        )
        assert out == [1, 1024, 1024**2, 1024**3]

    def test_decimal_values_are_kept(self, js):
        out = js("console.log(JSON.stringify(Docker.parseSize('1.5GiB')))")
        assert out == 1.5 * 1024**3

    def test_whitespace_between_number_and_unit_is_allowed(self, js):
        out = js("console.log(JSON.stringify(Docker.parseSize('  2 MB ')))")
        assert out == 2 * 1024**2

    def test_unparseable_input_is_nan(self, js):
        # NaN cannot cross JSON, so ask JS whether it is NaN.
        out = js(
            "console.log(JSON.stringify(["
            "isNaN(Docker.parseSize('')), isNaN(Docker.parseSize('nope')),"
            "isNaN(Docker.parseSize(null))]))"
        )
        assert out == [True, True, True]


class TestParsePullLine:
    def test_downloading_line_yields_bytes(self, js):
        out = js(
            'console.log(JSON.stringify(Docker.parsePullLine('
            '"abc123: Downloading [==>   ]  12.5MB/50MB")))'
        )
        assert out["id"] == "abc123"
        assert out["phase"] == "downloading"
        assert out["current"] == 12.5 * 1024**2
        assert out["total"] == 50 * 1024**2

    def test_extracting_line_is_recognised(self, js):
        out = js(
            'console.log(JSON.stringify(Docker.parsePullLine('
            '"deadbeef: Extracting  1GB/2GB")))'
        )
        assert out["phase"] == "extracting"

    def test_complete_line_has_no_byte_count(self, js):
        out = js(
            'console.log(JSON.stringify(Docker.parsePullLine("abc123: Pull complete")))'
        )
        assert out == {"id": "abc123", "phase": "complete", "current": None, "total": None}

    def test_already_exists_counts_as_complete(self, js):
        out = js(
            'console.log(JSON.stringify(Docker.parsePullLine("abc123: Already exists")))'
        )
        assert out["phase"] == "complete"

    def test_unrelated_lines_are_ignored(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Docker.parsePullLine('Pulling from library/nginx'),"
            "Docker.parsePullLine('Status: Downloaded newer image'),"
            "Docker.parsePullLine('')]))"
        )
        assert out == [None, None, None]


class TestAccumulateLayers:
    def test_empty_state_is_zero(self, js):
        out = js("console.log(JSON.stringify(Docker.accumulateLayers({})))")
        assert out == {"done": 0, "total": 0, "progress": 0}

    def test_layers_are_summed(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.accumulateLayers({"
            "a:{current:50,total:100}, b:{current:100,total:100}})))"
        )
        assert out["done"] == 150
        assert out["total"] == 200
        assert out["progress"] == 0.75

    def test_current_is_clamped_to_total(self, js):
        # A layer reporting more bytes than its total must not push progress
        # above 1.
        out = js(
            "console.log(JSON.stringify(Docker.accumulateLayers({"
            "a:{current:500,total:100}})))"
        )
        assert out["progress"] == 1

    def test_layers_without_totals_are_skipped(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.accumulateLayers({"
            "a:{current:10,total:0}, b:{current:10}})))"
        )
        assert out == {"done": 0, "total": 0, "progress": 0}

    def test_null_is_tolerated(self, js):
        out = js("console.log(JSON.stringify(Docker.accumulateLayers(null)))")
        assert out == {"done": 0, "total": 0, "progress": 0}


class TestStateTone:
    """Container state colours. Null means "use the theme's muted colour"."""

    def test_running_is_green(self, js):
        assert js('console.log(JSON.stringify(Docker.stateTone("running")))') == "#22c55e"

    def test_transitional_states_are_amber(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Docker.stateTone("restarting"), Docker.stateTone("paused"),'
            'Docker.stateTone("created")]))'
        )
        assert out == ["#eab308"] * 3

    def test_stopped_states_are_red(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Docker.stateTone("exited"), Docker.stateTone("dead"),'
            'Docker.stateTone("removing")]))'
        )
        assert out == ["#ef4444"] * 3

    def test_unknown_state_has_no_opinion(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Docker.stateTone("weird"), Docker.stateTone(""), Docker.stateTone(null)]))'
        )
        assert out == [None, None, None]

    def test_case_and_whitespace_are_ignored(self, js):
        assert js('console.log(JSON.stringify(Docker.stateTone("  RUNNING  ")))') == "#22c55e"


class TestStateBackground:
    def test_running_tint(self, js):
        assert js('console.log(JSON.stringify(Docker.stateBackground("running")))') == (
            "rgba(33, 196, 94, 0.18)"
        )

    def test_unknown_state_has_no_opinion(self, js):
        assert js('console.log(JSON.stringify(Docker.stateBackground("weird")))') is None

    def test_every_toned_state_has_a_background(self, js):
        # A state with a colour but no background would render as a bare chip.
        out = js(
            "console.log(JSON.stringify("
            "['running','restarting','paused','created','exited','dead','removing']"
            ".map(function (s) { return [Docker.stateTone(s), Docker.stateBackground(s)]; })))"
        )
        for tone, bg in out:
            assert tone is not None
            assert bg is not None


class TestRunningCount:
    def test_counts_running_only(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.runningCount("
            "[{running:true},{running:false},{running:true}])))"
        )
        assert out == 2

    def test_empty_and_null_are_zero(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Docker.runningCount([]), Docker.runningCount(null)]))"
        )
        assert out == [0, 0]

    def test_malformed_rows_are_skipped(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.runningCount("
            "[null,{running:true},{},{running:false}])))"
        )
        assert out == 1
