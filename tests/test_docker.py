"""Tests for model/Docker.mjs: command construction and `docker ps` parsing."""

import json
import subprocess


class TestCommands:
    def test_ps_lists_all_containers_with_tabs(self, js):
        out = js("console.log(JSON.stringify(Docker.psCommand()))")
        assert out[0] == "docker"
        assert out[1] == "ps"
        assert "-a" in out
        assert "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.Ports}}" in out

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


class TestRemoveGameServer:
    """Removal is destructive, so the command must be narrow and syntactically sound."""

    def test_target_is_positional_not_spliced_into_the_script(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.removeGameServerCommand("
            + json.dumps("RPG; touch /tmp/boom") + ")))"
        )
        assert out[0] == "sh"
        assert out[1] == "-c"
        assert out[3] == "sh"
        assert out[4] == "RPG; touch /tmp/boom"
        assert "RPG;" not in out[2]

    def test_script_removes_container_and_only_the_expected_data_dir(self, js):
        script = js('console.log(JSON.stringify(Docker.removeGameServerCommand("RPG")))')[2]
        subprocess.run(["sh", "-n"], input=script, text=True, check=True)
        for needle in (
            "docker inspect",
            '"$name"',
            "docker rm -f",
            "rm -rf --",
            '"$name-data"',
            "Refusing to delete reserved data path",
            "Refusing to delete data path with traversal",
            "Refusing to delete symlinked data dir",
        ):
            assert needle in script, needle + " missing from removal script"

    def test_empty_name_is_not_a_valid_target(self, js):
        out = js('console.log(JSON.stringify(Docker.removeGameServerCommand("  ")))')
        assert out[4] == ""


class TestMinecraftServerEditing:
    """Inspect, refresh and recreate keep the data dir and validate before acting."""

    def test_inspect_targets_one_container(self, js):
        out = js('console.log(JSON.stringify(Docker.inspectMinecraftServerCommand("RPG")))')
        assert out == ["docker", "inspect", "--format", "json", "RPG"]

    def test_parse_inspection_accepts_docker_format_json_array(self, js):
        # This is the shape `docker inspect --format json NAME` actually emits.
        raw = json.dumps([{
            "Name": "/bigheads",
            "Config": {
                "Image": "itzg/minecraft-server:latest",
                "Env": ["TYPE=PAPER", "VERSION=26.3", "SERVER_PORT=25580"],
            },
            "NetworkSettings": {"Ports": {"25580/tcp": [{"HostPort": "25580"}]}},
            "Mounts": [
                {"Destination": "/data",
                 "Source": "/mnt/games/GameServers/bigheads-data"},
            ],
        }])
        out = js("console.log(JSON.stringify(Docker.parseMinecraftServerInspection("
                 + json.dumps(raw) + ")))")
        assert out == {
            "name": "bigheads", "image": "itzg/minecraft-server:latest",
            "type": "PAPER", "version": "26.3", "memory": "", "difficulty": "",
            "port": 25580, "dataDir": "/mnt/games/GameServers/bigheads-data",
            "modsDir": "", "worldDir": "",
        }
        empty = js('console.log(JSON.stringify(Docker.parseMinecraftServerInspection("[]")))')
        assert empty["name"] == "" and empty["port"] == 0

    def test_parse_inspection_reads_env_image_and_mounts(self, js):
        raw = json.dumps({
            "Name": "/RPG",
            "Config": {
                "Image": "itzg/minecraft-server:java17",
                "Env": ["TYPE=FABRIC", "VERSION=1.20.1", "MEMORY=4G",
                        "DIFFICULTY=NORMAL", "SERVER_PORT=25570"],
            },
            "NetworkSettings": {"Ports": {"25570/tcp": [{"HostPort": "25570"}]}},
            "Mounts": [
                {"Destination": "/data", "Source": "/mnt/games/GameServers/RPG-data"},
                {"Destination": "/mods", "Source": "/home/elena/prism/mods"},
                {"Destination": "/worlds/source", "Source": "/home/elena/prism/saves/World"},
            ],
        })
        out = js("console.log(JSON.stringify(Docker.parseMinecraftServerInspection("
                 + json.dumps(raw) + ")))")
        assert out == {
            "name": "RPG", "image": "itzg/minecraft-server:java17",
            "type": "FABRIC", "version": "1.20.1", "memory": "4G",
            "difficulty": "NORMAL", "port": 25570,
            "dataDir": "/mnt/games/GameServers/RPG-data",
            "modsDir": "/home/elena/prism/mods",
            "worldDir": "/home/elena/prism/saves/World",
        }

    def test_parse_inspection_falls_back_to_published_port(self, js):
        raw = json.dumps({
            "Name": "/RPG", "Config": {"Image": "itzg/minecraft-server:latest", "Env": []},
            "NetworkSettings": {"Ports": {"25572/tcp": [{"HostPort": "25572"}]}},
            "Mounts": [],
        })
        out = js("console.log(JSON.stringify(Docker.parseMinecraftServerInspection("
                 + json.dumps(raw) + ")))")
        assert out["port"] == 25572

    def test_bad_inspection_is_empty_not_partial(self, js):
        out = js('console.log(JSON.stringify(Docker.parseMinecraftServerInspection("not json")))')
        assert out["name"] == "" and out["port"] == 0 and out["dataDir"] == ""

    def test_refresh_mods_is_positional_and_copies_support_dirs(self, js):
        data = "/mnt/games/GameServers/RPG-data"
        mods = "/home/elena/prism/mods"
        src = "/home/elena/prism/minecraft"
        out = js("console.log(JSON.stringify(Docker.refreshMinecraftModsCommand("
                 + json.dumps(data) + ", " + json.dumps(mods) + ", "
                 + json.dumps(src) + ")))")
        assert out[0] == "sh" and out[1] == "-c" and out[3] == "sh"
        assert out[4:7] == [data, mods, src]
        script = out[2]
        subprocess.run(["sh", "-n"], input=script, text=True, check=True)
        for needle in (
            "rm -rf --", 'cp -a "$mods"/.', "kubejs config defaultconfigs",
            "Refusing to refresh into reserved path",
            "Refusing to refresh into path with traversal",
        ):
            assert needle in script, needle + " missing from refresh script"

    def test_refresh_refuses_reserved_target_in_the_script(self, js):
        # Absolute reserved paths get a command, but the shell guard refuses
        # before any copy happens.
        cmd = js("console.log(JSON.stringify(Docker.refreshMinecraftModsCommand("
                 '"/mnt/games/GameServers", "/tmp/mods", "")))')
        assert cmd[:2] == ["sh", "-c"]
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        assert run.returncode == 2
        assert "Refusing to refresh into reserved path" in run.stderr

    def test_refresh_refuses_relative_target_in_the_model(self, js):
        # Non-absolute targets never become a command at all.
        out = js('console.log(JSON.stringify(Docker.refreshMinecraftModsCommand('
                 '"relative", "/tmp/mods", "")))')
        assert out == []

    @staticmethod
    def _recreate_out(js, name="bigheads", port=25571, data="/mnt/games/GameServers/RPG-data"):
        opts = {"name": name, "port": port, "type": "FABRIC", "version": "1.20.1",
                "memory": "4G", "difficulty": "NORMAL", "dataDir": data,
                "image": "itzg/minecraft-server:java17", "modsDir": "", "worldDir": ""}
        return js("console.log(JSON.stringify(Docker.recreateMinecraftServerCommand("
                  + json.dumps("RPG") + ", " + json.dumps(opts) + ")))")

    def test_recreate_is_positional_preserves_data_and_sets_server_port(self, js):
        out = self._recreate_out(js)
        assert out[0] == "sh" and out[1] == "-c" and out[3] == "sh"
        assert out[4:7] == ["RPG", "bigheads", "25571"]
        assert out[12] == "itzg/minecraft-server:java17"
        script = out[2]
        subprocess.run(["sh", "-n"], input=script, text=True, check=True)
        for needle in (
            'docker rm -f "$old"', 'docker run -d -it --name "$new"',
            '-p "$port:$port"', '-v "$data:/data"', '-e SERVER_PORT="$port"',
            '-e MEMORY="$memory"',
            'docker inspect "$new"', "Invalid container name", "Invalid Minecraft port",
            "Refusing to recreate against reserved data dir",
        ):
            assert needle in script, needle + " missing from recreate script"

    def test_recreate_defaults_image_from_version_when_none_supplied(self, js):
        opts = {"name": "bigheads", "port": 25571, "version": "1.20.1",
                "dataDir": "/mnt/games/GameServers/RPG-data"}
        out = js("console.log(JSON.stringify(Docker.recreateMinecraftServerCommand("
                 '"RPG", ' + json.dumps(opts) + ")))")
        assert out[12] == "itzg/minecraft-server:java17"

    def test_recreate_normalizes_unsafe_names_in_the_model(self, js):
        for bad_name in ("-bad", "bad;name", "bad name"):
            out = self._recreate_out(js, name=bad_name)
            assert out[5] == "vember-minecraft", bad_name + " was not normalized"

    def test_recreate_script_refuses_unsafe_args_before_docker(self, js):
        # Drive the shell guard directly, bypassing model normalization. This is
        # the defence-in-depth layer that protects a hand-built QML call.
        script = self._recreate_out(js)[2]
        bad_args = ["-bad", "RPG-new", "25571", "FABRIC", "1.20.1", "4G", "NORMAL",
                    "/mnt/games/GameServers/RPG-data", "itzg/minecraft-server:java17", "", ""]
        run = subprocess.run(["sh", "-c", script, "sh"] + bad_args,
                             capture_output=True, text=True, timeout=30)
        assert run.returncode == 2
        assert "Invalid container name" in run.stderr


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
                "ports": "",
                "webUrl": "",
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


class TestMinecraftServerCommands:
    def test_default_is_paper_on_lan_with_persistent_data(self, js):
        opts = js(
            "console.log(JSON.stringify(Docker.normalizeMinecraftServerOptions({})))"
        )
        assert opts == {
            "name": "vember-minecraft", "type": "PAPER", "version": "LATEST",
            "memory": "4G", "difficulty": "NORMAL",
            "dataDir": "/mnt/games/GameServers/vember-minecraft-data", "port": 25565,
            "modsDir": "", "worldDir": "",
        }
        cmd = js("console.log(JSON.stringify(Docker.createMinecraftServerCommand({})))")
        assert cmd[:4] == ["docker", "run", "-d", "-it"]
        assert cmd[cmd.index("--name") + 1] == "vember-minecraft"
        assert cmd[cmd.index("--restart") + 1] == "unless-stopped"
        assert "25565:25565" in cmd
        assert "/mnt/games/GameServers/vember-minecraft-data:/data" in cmd
        for env in ("EULA=TRUE", "TYPE=PAPER", "VERSION=LATEST", "MEMORY=4G",
                    "DIFFICULTY=NORMAL", "SERVER_PORT=25565"):
            assert env in cmd
        assert cmd[-1] == "itzg/minecraft-server:latest"
        # RCON is enabled inside the container but must never reach the host.
        assert not any("25575" in part for part in cmd)

    def test_all_four_server_types_build_a_type_env(self, js):
        for kind in ("VANILLA", "PAPER", "FORGE", "FABRIC"):
            cmd = js(
                "console.log(JSON.stringify(Docker.createMinecraftServerCommand("
                '{{type:"{0}"}})))'.format(kind)
            )
            assert "TYPE=" + kind in cmd

    def test_invalid_inputs_fall_back_to_safe_defaults(self, js):
        opts = js(
            "console.log(JSON.stringify(Docker.normalizeMinecraftServerOptions({"
            'name:"bad name; rm -rf /", type:"EVIL", version:"../../etc",'
            ' memory:"9999G", dataDir:"relative/path", port:99999'
            "})))"
        )
        assert opts["name"] == "vember-minecraft"
        assert opts["type"] == "PAPER"
        assert opts["version"] == "LATEST"
        assert opts["memory"] == "4G"
        assert opts["difficulty"] == "NORMAL"
        assert opts["dataDir"] == "/mnt/games/GameServers/vember-minecraft-data"
        assert opts["port"] == 25565
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'name:"bad name; rm -rf /"})))'
        )
        assert "rm -rf" not in " ".join(cmd)

    def test_forge_version_and_custom_values_are_kept(self, js):
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'type:"forge", version:"1.20.1-47.2.0", memory:"6G",'
            ' name:"modded-world", dataDir:"/tmp/mc", port:25566'
            "})))"
        )
        for expected in (
            "TYPE=FORGE", "VERSION=1.20.1-47.2.0", "MEMORY=6G",
            "25566:25566", "/tmp/mc:/data", "modded-world",
        ):
            assert expected in cmd

    def test_difficulty_and_portable_default_are_honoured(self, js):
        opts = js(
            "console.log(JSON.stringify(Docker.normalizeMinecraftServerOptions({"
            'difficulty:"peaceful", defaultDataDir:"/home/someone/minecraft-servers"'
            "})))"
        )
        assert opts["difficulty"] == "PEACEFUL"
        assert opts["dataDir"] == "/home/someone/minecraft-servers/vember-minecraft-data"
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'difficulty:"hard", dataDir:"/srv/mc", port:25566'
            "})))"
        )
        assert "DIFFICULTY=HARD" in cmd
        assert "25566:25566" in cmd

    def test_data_dir_is_derived_from_name_so_servers_do_not_share_a_world(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.minecraftDataDir("
            '"nodecraft", "/mnt/games/GameServers")))'
        )
        assert out == "/mnt/games/GameServers/nodecraft-data"
        other = js(
            "console.log(JSON.stringify(Docker.minecraftDataDir("
            '"vember-minecraft", "/mnt/games/GameServers")))'
        )
        assert other == "/mnt/games/GameServers/vember-minecraft-data"
        assert out != other

    def test_named_server_gets_its_own_bind_without_an_explicit_dir(self, js):
        opts = js(
            "console.log(JSON.stringify(Docker.normalizeMinecraftServerOptions({"
            'name:"nodecraft", defaultDataDir:"/mnt/games/GameServers"'
            "})))"
        )
        assert opts["dataDir"] == "/mnt/games/GameServers/nodecraft-data"
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'name:"nodecraft", defaultDataDir:"/mnt/games/GameServers"'
            "})))"
        )
        assert "/mnt/games/GameServers/nodecraft-data:/data" in cmd

    def test_image_tracks_game_version_jdk_requirement(self, js):
        # :latest now ships Java 25. 1.18-era modpacks need Java 17, and
        # 1.20.5+/1.21.x modpacks need Java 21 (Spark's native profiler
        # SIGSEGVs on JDK 25). An explicit LATEST game stays on :latest.
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage()))") == \
            "itzg/minecraft-server:latest"
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage('LATEST')))") == \
            "itzg/minecraft-server:latest"
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage('1.18.2')))") == \
            "itzg/minecraft-server:java17"
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage('1.20.1')))") == \
            "itzg/minecraft-server:java17"
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage('1.20.5')))") == \
            "itzg/minecraft-server:java21"
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage('1.21')))") == \
            "itzg/minecraft-server:java21"
        assert js("console.log(JSON.stringify(Docker.minecraftServerImage('1.21.1')))") == \
            "itzg/minecraft-server:java21"

    def test_old_version_command_uses_java17_and_published_port(self, js):
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'name:"nodecraft", type:"FABRIC", version:"1.18.2", port:25566'
            "})))"
        )
        assert "SERVER_PORT=25566" in cmd
        assert "25566:25566" in cmd
        assert cmd[-1] == "itzg/minecraft-server:java17"

    def test_preflight_commands_are_shaped_for_the_wizard(self, js):
        check = js("console.log(JSON.stringify(Docker.dockerReadyCommand()))")
        assert check[0] == "sh" and "docker info" in check[2]
        inspect = js("console.log(JSON.stringify(Docker.minecraftServerImageCheckCommand()))")
        assert inspect == ["docker", "image", "inspect", "itzg/minecraft-server:latest"]
        old = js(
            "console.log(JSON.stringify(Docker.minecraftServerImageCheckCommand('1.18.2')))"
        )
        assert old == ["docker", "image", "inspect", "itzg/minecraft-server:java17"]
        modern = js(
            "console.log(JSON.stringify(Docker.minecraftServerImageCheckCommand('1.21.1')))"
        )
        assert modern == ["docker", "image", "inspect", "itzg/minecraft-server:java21"]

    def test_logs_and_inspect_commands(self, js):
        assert js(
            'console.log(JSON.stringify(Docker.logsCommand("vember-minecraft", 100)))'
        ) == ["docker", "logs", "--tail", "100", "vember-minecraft"]
        # A bad line count falls back to 200 rather than passing garbage.
        assert js(
            'console.log(JSON.stringify(Docker.logsCommand("mc", "oops")))'
        ) == ["docker", "logs", "--tail", "200", "mc"]
        inspect = js(
            'console.log(JSON.stringify(Docker.inspectDataDirCommand("mc")))'
        )
        assert inspect[:3] == ["docker", "inspect", "--format"]
        assert ".Destination" in inspect[3] and ".Source" in inspect[3]
        assert inspect[-1] == "mc"


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


class TestContainerWebUrls:
    """One-click browser open is derived from published ports, never labels."""

    def test_wildcard_and_loopback_become_localhost(self, js):
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"0.0.0.0:14444->8080/tcp")))') == "http://localhost:14444"
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"127.0.0.1:8610->8000/tcp")))') == "http://localhost:8610"
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"[::]:14444->8080/tcp")))') == "http://localhost:14444"

    def test_literal_lan_address_is_kept(self, js):
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"192.168.0.145:9999->8000/tcp")))') == "http://192.168.0.145:9999"
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"100.106.232.82:8580->8580/tcp")))') == "http://100.106.232.82:8580"

    def test_ipv6_bind_is_bracketed(self, js):
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"[fd00::5]:8080->8080/tcp")))') == "http://[fd00::5]:8080"

    def test_unpublished_and_non_web_ports_are_rejected(self, js):
        for ports in (
            "5432/tcp",                         # no host binding
            "0.0.0.0:25565->25565/tcp",          # Minecraft
            "0.0.0.0:5432->5432/tcp",            # postgres
            "0.0.0.0:5353->53/udp",              # UDP is not a browser page
            "evil.example.com:8080->8080/tcp",   # never trust a name
            "",
        ):
            assert js("console.log(JSON.stringify(Docker.webUrlFromPorts("
                      + __import__("json").dumps(ports) + ")))") == "", ports

    def test_https_and_preferred_web_port_win(self, js):
        # Two candidates: prefer the real web port over the game port, and
        # prefer https when both are plausible.
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"0.0.0.0:25565->25565/tcp,0.0.0.0:18080->8080/tcp")))') == (
            "http://localhost:18080")
        assert js('console.log(JSON.stringify(Docker.webUrlFromPorts('
                  '"0.0.0.0:10080->80/tcp,0.0.0.0:10443->443/tcp")))') == (
            "https://localhost:10443")

    def test_parse_ps_attaches_ports_and_url(self, js):
        out = js(
            "console.log(JSON.stringify(Docker.parsePs("
            '"web\tnginx\trunning\tUp 1 min\t192.168.0.145:9999->8000/tcp")))'
        )
        assert out[0]["ports"] == "192.168.0.145:9999->8000/tcp"
        assert out[0]["webUrl"] == "http://192.168.0.145:9999"


class TestComposeApply:
    """Apply update recreates a Compose service from the container's own labels."""

    def test_inspect_command_reads_all_four_labels(self, js):
        cmd = js('console.log(JSON.stringify(Docker.inspectComposeCommand("web")))')
        assert cmd[:3] == ["docker", "inspect", "--format"]
        assert cmd[-1] == "web"
        fmt = cmd[3]
        for key in ("project.config_files", "project.working_dir", "project", "service"):
            assert "com.docker.compose." + key in fmt
        assert "|~|" in fmt
        assert js('console.log(JSON.stringify(Docker.inspectComposeCommand("  ")))') == []

    def test_parse_real_label_shape(self, js):
        out = js(
            'console.log(JSON.stringify(Docker.parseComposeInfo('
            '"/home/elena/containers/paperless-ngx/docker-compose.yml|~|'
            '/home/elena/containers/paperless-ngx|~|paperless-ngx|~|webserver")))'
        )
        assert out["files"] == ["/home/elena/containers/paperless-ngx/docker-compose.yml"]
        assert out["workingDir"] == "/home/elena/containers/paperless-ngx"
        assert out["project"] == "paperless-ngx"
        assert out["service"] == "webserver"

    def test_parse_multiple_compose_files_in_order(self, js):
        out = js(
            'console.log(JSON.stringify(Docker.parseComposeInfo('
            '"/a/base.yml, /a/override.yml|~|/a|~|proj|~|svc")))'
        )
        assert out["files"] == ["/a/base.yml", "/a/override.yml"]

    def test_parse_rejects_unsafe_values(self, js):
        for raw in (
            "",
            "garbage",
            "relative.yml|~|/a|~|proj|~|svc",
            "/a/c.yml|~|relative|~|proj|~|svc",
            "/a/c.yml|~|/a|~|bad project|~|svc",
            "/a/c.yml|~|/a|~|proj|~|bad service!",
            "/a/c.yml|~|/a|~|proj",
        ):
            assert js("console.log(JSON.stringify(Docker.parseComposeInfo("
                      + __import__("json").dumps(raw) + ")))") is None, raw

    def test_apply_command_uses_no_deps_and_project_directory(self, js):
        info = {
            "files": ["/a/base.yml", "/a/override.yml"],
            "workingDir": "/a",
            "project": "paperless-ngx",
            "service": "webserver",
        }
        argv = js("console.log(JSON.stringify(Docker.applyComposeUpdateCommand("
                  + __import__("json").dumps(info) + ")))")
        assert argv == [
            "docker", "compose", "--project-directory", "/a",
            "-f", "/a/base.yml", "-f", "/a/override.yml",
            "-p", "paperless-ngx", "up", "-d", "--no-deps", "webserver",
        ]
        assert js("console.log(JSON.stringify(Docker.applyComposeUpdateCommand(null)))") == []


class TestModpackMounts:
    def test_modpack_mods_and_world_are_mounted_read_only(self, js):
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'name:"create-server", type:"FORGE", version:"1.20.1-47.4.28", '
            'modsDir:"/home/someone/mods", worldDir:"/home/someone/saves/New World"'
            "})))"
        )
        assert "-v" in cmd and "/home/someone/mods:/mods:ro" in cmd
        assert "/home/someone/saves/New World:/worlds/source:ro" in cmd
        assert "WORLD=/worlds/source" in cmd
        assert cmd[-1] == "itzg/minecraft-server:java17"

    def test_unsafe_mount_paths_are_dropped(self, js):
        opts = js(
            "console.log(JSON.stringify(Docker.normalizeMinecraftServerOptions({"
            'modsDir:"relative/mods", worldDir:"/a/b:\\evil"'
            "})))"
        )
        assert opts["modsDir"] == ""
        assert opts["worldDir"] == ""
        cmd = js(
            "console.log(JSON.stringify(Docker.createMinecraftServerCommand({"
            'modsDir:"relative/mods", worldDir:"/a/b:\\evil"'
            "})))"
        )
        assert "WORLD=" not in " ".join(cmd)
        assert ":/mods:ro" not in " ".join(cmd)

    def test_kubejs_config_is_staged_into_the_server_data_dir(self, js):
        cmd = js(
            "console.log(JSON.stringify(Docker.stageModpackDataCommand("
            '"/mnt/games/GameServers/nodecraft-data", '
            '"/home/elena/.local/share/PrismLauncher/instances/Create- Astral/minecraft"'
            ")))"
        )
        assert cmd[0] == "sh" and cmd[1] == "-c"
        script = cmd[2]
        for name in ("kubejs", "config", "defaultconfigs"):
            assert name in script
        assert "cp -a" in script
        assert "'/mnt/games/GameServers/nodecraft-data/kubejs'" in script
        # Spaces in "Create- Astral" survive the shell quoting.
        assert "'/home/elena/.local/share/PrismLauncher/instances/Create- Astral/minecraft/kubejs'" in script

    def test_unsafe_stage_paths_are_dropped(self, js):
        for data, src in (("relative/data", "/ok/src"),
                          ("/ok/data", "relative/src"),
                          ("/ok/data\nx", "/ok/src")):
            argv = js("console.log(JSON.stringify(Docker.stageModpackDataCommand("
                      + __import__("json").dumps(data) + ", "
                      + __import__("json").dumps(src) + ")))")
            assert argv == []


class TestDockerPublishedPorts:
    def test_only_published_host_ports_count(self, js):
        text = ("0.0.0.0:25565->25565/tcp, [::]:25565->25565/tcp, "
                "5432/tcp, 127.0.0.1:8610->8000/tcp, "
                "0.0.0.0:25575->25575/udp, 25576/udp")
        ports = js("console.log(JSON.stringify(Docker.publishedPorts("
                   + __import__("json").dumps(text) + ")))")
        assert ports == [8610, 25565, 25575]


class TestStats:
    def test_command_is_one_shot_with_name_and_memory(self, js):
        out = js("console.log(JSON.stringify(Docker.statsCommand()))")
        assert out[:2] == ["docker", "stats"]
        assert "--no-stream" in out
        assert "{{.Name}}\t{{.MemUsage}}" in out

    def test_sums_used_memory_across_rows(self, js):
        text = "web\t1.5GiB / 8GiB\ndb\t256MiB / 8GiB\nodd\tno memory here"
        out = js("console.log(JSON.stringify(Docker.parseStats(" + json.dumps(text) + ")))")
        assert out == {"totalBytes": int(1.5 * 1024 ** 3 + 256 * 1024 ** 2), "containers": 2}

    def test_empty_and_unparseable_input(self, js):
        for text in ("", "\n\n", "web\tunknown / 8GiB"):
            out = js("console.log(JSON.stringify(Docker.parseStats(" + json.dumps(text) + ")))")
            assert out == {"totalBytes": 0, "containers": 0}

    def test_small_units_are_parsed(self, js):
        out = js("console.log(JSON.stringify(Docker.parseStats("
                 + json.dumps("web\t2.5KiB / 8GiB") + ")))")
        assert out == {"totalBytes": 2560, "containers": 1}
