"""Tests for model/Gaming.mjs: catalog, Steam and Battle.net helpers."""

import json
import socket
import struct
import subprocess
from pathlib import Path


class TestCatalog:
    def test_every_entry_has_the_fields_the_ui_needs(self, js):
        out = js("console.log(JSON.stringify(Gaming.catalog()))")
        assert len(out) >= 5
        for app in out:
            assert app["id"]
            assert app["name"]
            assert app["category"]
            assert isinstance(app["launchCmd"], list) and app["launchCmd"]
            assert isinstance(app["installCmd"], str) and app["installCmd"]

    def test_ids_are_unique(self, js):
        out = js(
            "console.log(JSON.stringify(new Set(Gaming.catalog().map(a => a.id)).size))"
        )
        total = js("console.log(JSON.stringify(Gaming.catalog().length))")
        assert out == total

    def test_known_launcher_is_present(self, js):
        out = js('console.log(JSON.stringify(Gaming.defById("lutris")))')
        assert out["name"] == "Lutris"
        assert out["category"] == "launchers"

    def test_unknown_id_returns_null(self, js):
        out = js('console.log(JSON.stringify(Gaming.defById("nope")))')
        assert out is None

    def test_retired_official_launcher_is_absent(self, js):
        out = js('console.log(JSON.stringify(Gaming.defById("minecraft-launcher")))')
        assert out is None


class TestScan:
    def test_installed_and_running_flags_are_parsed(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parseScan("
            '"lutris\\t1\\t1\\t\\n", Gaming.catalog())))'
        )
        lutris = next(a for a in out if a["id"] == "lutris")
        assert lutris["installed"] is True
        assert lutris["running"] is True

    def test_missing_rows_default_to_not_installed(self, js):
        out = js('console.log(JSON.stringify(Gaming.parseScan("", Gaming.catalog())))')
        assert all(a["installed"] is False for a in out)
        assert all(a["running"] is False for a in out)

    def test_every_catalog_entry_is_returned_even_without_scan_data(self, js):
        out = js('console.log(JSON.stringify(Gaming.parseScan("", Gaming.catalog())))')
        total = js("console.log(JSON.stringify(Gaming.catalog().length))")
        assert len(out) == total

    def test_note_is_carried_through(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parseScan("
            '"curseforge\\t1\\t0\\t/home/x/Applications/CurseForge.AppImage\\n",'
            " Gaming.catalog())))"
        )
        cf = next(a for a in out if a["id"] == "curseforge")
        assert cf["note"] == "/home/x/Applications/CurseForge.AppImage"

    def test_tolerates_a_missing_catalog(self, js):
        out = js('console.log(JSON.stringify(Gaming.parseScan("lutris\\t1\\t0\\t", null)))')
        assert out == []

    def test_scan_script_is_valid_sh(self, js):
        cmd = js("console.log(JSON.stringify(Gaming.scanCommand()))")
        assert cmd[0] == "sh"
        result = subprocess.run(
            ["sh", "-n"], input=cmd[2], capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr


class TestSteam:
    def test_manifest_scan_reads_json(self, js):
        out = js(
            'console.log(JSON.stringify(Gaming.parseSteamManifestScan('
            '\'{"count":7,"servers":[{"appid":"1","name":"Srv","installdir":"s"}]}\')))'
        )
        assert out["count"] == 7
        assert out["servers"] == [{"appid": "1", "name": "Srv", "installdir": "s"}]

    def test_plain_number_is_a_count(self, js):
        out = js('console.log(JSON.stringify(Gaming.parseSteamManifestScan("12")))')
        assert out == {"count": 12, "servers": []}

    def test_line_fallback_counts_rows(self, js):
        out = js(
            'console.log(JSON.stringify(Gaming.parseSteamManifestScan("a\\nb\\nc")))'
        )
        assert out["count"] == 3

    def test_empty_input_is_zero(self, js):
        out = js('console.log(JSON.stringify(Gaming.parseSteamManifestScan("   ")))')
        assert out == {"count": 0, "servers": []}


    def test_library_paths_are_extracted_from_vdf(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parseLibraryPaths("
            '\'"libraryfolders"\\n{\\n"path"\\t\\t"/mnt/games/Steam"\\n}\')))'
        )
        assert out == ["/mnt/games/Steam"]

    def test_escaped_backslashes_are_unescaped(self, js):
        out = js(
            'console.log(JSON.stringify(Gaming.parseLibraryPaths(\'"path" "D:\\\\\\\\Games"\')))'
        )
        assert out == ["D:\\Games"]

    def test_empty_vdf_yields_no_paths(self, js):
        assert js('console.log(JSON.stringify(Gaming.parseLibraryPaths("")))') == []


    def test_multi_dir_command_without_dirs_is_a_zero_json_stub(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.steamManifestCountCommandForDirs([])))"
        )
        assert out[0] == "python3"
        assert "'count': 0" in out[2]

    def test_multi_dir_command_appends_only_non_blank_dirs(self, js):
        out = js(
            'console.log(JSON.stringify(Gaming.steamManifestCountCommandForDirs('
            '["/mnt/a", "  ", "/mnt/b"])))'
        )
        assert out[0] == "python3"
        assert out[-2:] == ["/mnt/a", "/mnt/b"]

    def test_multi_dir_script_is_valid_python(self, js):
        out = js(
            'console.log(JSON.stringify(Gaming.steamManifestCountCommandForDirs(["/mnt/a"])))'
        )
        result = subprocess.run(
            ["python3", "-c", "import ast,sys; ast.parse(sys.stdin.read())"],
            input=out[2],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stderr


class TestBattlenet:
    def test_install_command_prefers_pacman(self, js):
        assert "pacman" in js("console.log(JSON.stringify(Gaming.steamInstallCommand()))")

    def test_setup_url_points_at_lutris(self, js):
        assert js("console.log(JSON.stringify(Gaming.battlenetSetupUrl()))").startswith(
            "https://lutris.net/"
        )

    def test_game_count_command_searches_marker_files(self, js):
        out = js(
            'console.log(JSON.stringify(Gaming.battlenetGameCountCommand("/home/x")))'
        )
        assert out[0] == "find"
        assert "/home/x/Games/battlenet" in out
        assert ".build.info" in out and ".product.db" in out

    def test_markers_in_one_directory_count_once(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parseBattlenetGameCount("
            '"/g/Game1/.build.info\\n/g/Game1/.product.db\\n")))'
        )
        assert out == 1

    def test_distinct_directories_each_count(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parseBattlenetGameCount("
            '"/g/A/.build.info\\n/g/B/.build.info\\n")))'
        )
        assert out == 2

    def test_empty_scan_is_zero(self, js):
        assert js('console.log(JSON.stringify(Gaming.parseBattlenetGameCount("")))') == 0


class TestPaths:
    def test_steam_and_battlenet_paths_hang_off_home(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Gaming.steamRootPath("/h"), Gaming.steamLibraryVdfPath("/h"),'
            'Gaming.battlenetPrefixPath("/h")]))'
        )
        assert out == [
            "/h/.local/share/Steam",
            "/h/.local/share/Steam/steamapps/libraryfolders.vdf",
            "/h/Games/battlenet",
        ]


class TestVesktopIsDiscord:
    """Vesktop is a Discord client, not a separate thing to install."""

    def test_catalog_row_launches_vesktop(self, js):
        app = js('console.log(JSON.stringify(Gaming.defById("discord")))')
        assert "Vesktop" in app["name"]
        launch = app["launchCmd"][-1]
        assert "vesktop" in launch
        assert "Vesktop" in launch
        assert "dev.vencord.Vesktop" in launch
        assert app["installCmd"], "the row must still offer to install Discord"

    def test_scan_detects_native_and_flatpak_vesktop(self, js):
        script = js("console.log(JSON.stringify(Gaming.scanCommand()[2]))")
        assert "has_cmd vesktop" in script
        assert "has_cmd Vesktop" in script
        assert "has_flatpak dev.vencord.Vesktop" in script
        assert "running_any discord Discord vesktop Vesktop" in script

    def test_scan_emits_discord_as_installed_with_a_vesktop_stub(self, js, tmp_path):
        bindir = tmp_path / "bin"
        bindir.mkdir()
        stub = bindir / "vesktop"
        stub.write_text("#!/bin/sh\nexit 0\n")
        stub.chmod(0o755)
        env_path = str(bindir) + ":/usr/bin:/bin"
        cmd = js("console.log(JSON.stringify(Gaming.scanCommand()))")
        import os

        result = subprocess.run(
            cmd, capture_output=True, text=True,
            env=dict(os.environ, PATH=env_path),
        )
        assert result.returncode == 0, result.stderr
        row = next(line for line in result.stdout.splitlines() if line.startswith("discord\t"))
        assert row.split("\t")[1] == "1", "Vesktop should mark the Discord row installed"


class TestPrismInstanceCount:
    """Prism modpacks are a real part of the game library.

    Instance names contain spaces, so a glob interpolated into a shell string
    splits them. The scan has to quote its roots and let find walk them.
    """

    def test_command_checks_native_and_flatpak_roots(self, js):
        cmd = js('console.log(JSON.stringify(Gaming.prismInstanceCountCommand("/h")))')
        assert cmd[0:3] == ["sh", "-c", cmd[2]]
        assert cmd[3] == "sh"
        assert "/h/.local/share/PrismLauncher/instances" in cmd
        assert "/h/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances" in cmd
        assert 'for d in "$@"' in cmd[2]
        assert '[ -d "$d" ]' in cmd[2]
        assert 'find "$d"' in cmd[2]
        assert "-mindepth 2 -maxdepth 2" in cmd[2]
        assert "instance.cfg" in cmd[2]

    def test_parser_counts_paths_with_spaces_and_skips_blanks(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parsePrismInstanceCount("
            '"/i/Create- Astral/instance.cfg\\n\\n  \\n/i/Another One/instance.cfg\\n")))'
        )
        assert out == 2

    def test_parser_returns_zero_for_empty_output(self, js):
        assert js('console.log(JSON.stringify(Gaming.parsePrismInstanceCount("")))') == 0

    def test_real_scan_ignores_tmp_strays_and_nested_files(self, js, tmp_path):
        root = tmp_path / ".local" / "share" / "PrismLauncher" / "instances"
        (root / "Create- Astral").mkdir(parents=True)
        (root / "Create- Astral" / "instance.cfg").write_text("[General]\n")
        (root / "Vanilla").mkdir()
        (root / "Vanilla" / "instance.cfg").write_text("[General]\n")
        (root / ".tmp").mkdir()
        (root / "instgroups.json").write_text("{}")
        (root / "NotAnInstance").mkdir()
        (root / "NotAnInstance" / "other.cfg").write_text("x")
        too_deep = root / "Deep" / "nested"
        too_deep.mkdir(parents=True)
        (too_deep / "instance.cfg").write_text("x")

        cmd = js(
            "console.log(JSON.stringify(Gaming.prismInstanceCountCommand("
            + json.dumps(str(tmp_path)) + ")))"
        )
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        assert js(
            "console.log(JSON.stringify(Gaming.parsePrismInstanceCount("
            + json.dumps(result.stdout) + ")))"
        ) == 2


class TestMinecraftVersionCount:
    """Vanilla launcher versions feed the library total too.

    The launcher stores each version as <versions>/<name>/<name>.json. The two
    manifest files at the top level are not versions, so only depth-2 files
    count, and folder count is used rather than file count.
    """

    def test_command_checks_native_and_flatpak_roots(self, js):
        cmd = js('console.log(JSON.stringify(Gaming.minecraftVersionCountCommand("/h")))')
        assert cmd[0] == "sh" and cmd[1] == "-c" and cmd[3] == "sh"
        assert "/h/.minecraft/versions" in cmd
        assert "/h/.var/app/com.mojang.Minecraft/.minecraft/versions" in cmd
        assert 'for d in "$@"' in cmd[2]
        assert '[ -d "$d" ]' in cmd[2]
        assert "-mindepth 2 -maxdepth 2" in cmd[2]
        assert "'*.json'" in cmd[2]

    def test_parser_counts_folders_not_files(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.parseMinecraftVersionCount("
            + json.dumps(
                "/v/26.3/26.3.json\n/v/26.3/26.3-extra.json\n/v/26.4 snap/26.4 snap.json\n\n  \n"
            )
            + ")))"
        )
        assert out == 2, "two folders, three files — count folders"

    def test_parser_returns_zero_for_empty_output(self, js):
        assert js('console.log(JSON.stringify(Gaming.parseMinecraftVersionCount("")))') == 0

    def test_real_scan_ignores_top_level_manifests(self, js, tmp_path):
        root = tmp_path / ".minecraft" / "versions"
        (root / "26.3").mkdir(parents=True)
        (root / "26.3" / "26.3.json").write_text("{}")
        (root / "26.4-snapshot").mkdir()
        (root / "26.4-snapshot" / "26.4-snapshot.json").write_text("{}")
        (root / "version_manifest_v2.json").write_text("{}")
        (root / "jre_manifest.json").write_text("{}")
        (root / "Orphan").mkdir()
        (root / "Orphan" / "readme.txt").write_text("x")
        too_deep = root / "Deep" / "nested"
        too_deep.mkdir(parents=True)
        (too_deep / "Deep.json").write_text("{}")

        cmd = js(
            "console.log(JSON.stringify(Gaming.minecraftVersionCountCommand("
            + json.dumps(str(tmp_path)) + ")))"
        )
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        assert js(
            "console.log(JSON.stringify(Gaming.parseMinecraftVersionCount("
            + json.dumps(result.stdout) + ")))"
        ) == 2


class TestHeroicGameCount:
    """Heroic's install-info registries are its own list of installed games."""

    def test_command_checks_native_and_flatpak_roots_and_all_stores(self, js):
        cmd = js('console.log(JSON.stringify(Gaming.heroicGameCountCommand("/h")))')
        assert cmd[0] == "python3" and cmd[1] == "-c"
        script = cmd[2]
        assert "legendary" in script and "gog" in script and "nile" in script
        assert "install_info.json" in script
        assert "'__timestamp'" in script, "the timestamp bookkeeping key is not a game"
        assert "/h/.config/heroic" in cmd
        assert "/h/.var/app/com.heroicgameslauncher.hgl/config/heroic" in cmd

    def test_parser_reads_a_count_and_rejects_garbage(self, js):
        assert js('console.log(JSON.stringify(Gaming.parseHeroicGameCount("3\\n")))') == 3
        assert js('console.log(JSON.stringify(Gaming.parseHeroicGameCount("oops")))') == 0
        assert js('console.log(JSON.stringify(Gaming.parseHeroicGameCount("")))') == 0

    def test_real_scan_counts_distinct_games_across_stores(self, js, tmp_path):
        cache = tmp_path / ".config" / "heroic" / "store_cache"
        cache.mkdir(parents=True)
        (cache / "legendary_install_info.json").write_text(json.dumps({
            "app-one": {"install": {"installPath": "/games/one"}},
            "app-shared": {"install": {"installPath": "/games/shared"}},
            "__timestamp": {"app-one": "now"},
        }))
        (cache / "gog_install_info.json").write_text(json.dumps({
            "app-shared": {"install": {"installPath": "/games/shared"}},
            "app-two": {"install": {"installPath": "/games/two"}},
            "__timestamp": {},
        }))
        (cache / "nile_install_info.json").write_text(json.dumps({"__timestamp": {}}))

        cmd = js(
            "console.log(JSON.stringify(Gaming.heroicGameCountCommand("
            + json.dumps(str(tmp_path)) + ")))"
        )
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        # app-one, app-shared (deduped across stores), app-two; not __timestamp.
        assert js(
            "console.log(JSON.stringify(Gaming.parseHeroicGameCount("
            + json.dumps(result.stdout) + ")))"
        ) == 3

    def test_missing_registries_yield_zero(self, js, tmp_path):
        cmd = js(
            "console.log(JSON.stringify(Gaming.heroicGameCountCommand("
            + json.dumps(str(tmp_path)) + ")))"
        )
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        assert js(
            "console.log(JSON.stringify(Gaming.parseHeroicGameCount("
            + json.dumps(result.stdout) + ")))"
        ) == 0


class TestGameServerDetectionAndSizes:
    """Servers and Storage share one detection list and one size query."""

    def test_detection_keywords_are_shared(self, js):
        keys = js("console.log(JSON.stringify(Gaming.gameServerKeywords()))")
        for key in ("minecraft", "valheim", "factorio", "steamcmd"):
            assert key in keys
        assert len(keys) == len(set(keys))

    def test_detection_matches_image_and_adds_steam_servers(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.gameServerContainers("
            '[{name:"vember-minecraft",image:"itzg/minecraft-server:latest",'
            'state:"running",status:"up"},'
            '{name:"postgres",image:"postgres:16"}],'
            '[{name:"CS2",appid:"162990",installdir:"/mnt/games/cs2"}])))'
        )
        assert len(out) == 2
        assert out[0] == {
            "serverType": "container", "name": "vember-minecraft",
            "image": "itzg/minecraft-server:latest", "state": "running",
            "status": "up", "ports": "",
        }
        assert out[1]["serverType"] == "steam"
        assert out[1]["installdir"] == "/mnt/games/cs2"
        assert out[1]["image"] == "AppID 162990"

    def test_detection_handles_null_and_missing_fields(self, js):
        assert js(
            "console.log(JSON.stringify(Gaming.gameServerContainers(null, null)))"
        ) == []
        out = js(
            "console.log(JSON.stringify(Gaming.gameServerContainers([{}],[{}])))"
        )
        assert len(out) == 1  # the empty container does not match a keyword
        assert out[0]["name"] == "Steam Dedicated Server"

    def test_client_bar_uses_detected_servers_not_a_hardcoded_name(self, js):
        containers = [
            {"name": "RPG", "image": "itzg/minecraft-server:java17",
             "ports": "0.0.0.0:25570->25570/tcp"},
            {"name": "bigheads", "image": "itzg/minecraft-server:latest",
             "ports": "0.0.0.0:25571->25571/tcp, [::]:25571->25571/tcp"},
            {"name": "postgres", "image": "postgres:16",
             "ports": "0.0.0.0:5432->5432/tcp"},
        ]
        out = js("console.log(JSON.stringify(Gaming.minecraftServers("
                 + json.dumps(containers) + ")))")
        assert out == [
            {"name": "RPG", "image": "itzg/minecraft-server:java17", "port": 25570},
            {"name": "bigheads", "image": "itzg/minecraft-server:latest", "port": 25571},
        ]

    def test_minecraft_predicate_matches_image_and_name(self, js):
        yes = js("console.log(JSON.stringify(Gaming.isMinecraftContainer("
                 '{name:"my-minecraft",image:"custom"})))')
        by_image = js("console.log(JSON.stringify(Gaming.isMinecraftContainer("
                      '{name:"RPG",image:"itzg/minecraft-server:java17"})))')
        no = js("console.log(JSON.stringify(Gaming.isMinecraftContainer("
                '{name:"postgres",image:"postgres:16"})))')
        assert yes is True and by_image is True and no is False

    def test_minecraft_server_without_published_port_has_zero(self, js):
        out = js('console.log(JSON.stringify(Gaming.minecraftServers('
                 '[{name:"RPG",image:"itzg/minecraft-server:java17"}])))')
        assert out == [{"name": "RPG", "image": "itzg/minecraft-server:java17", "port": 0}]

    def test_size_command_passes_names_as_args_not_script(self, js):
        cmd = js(
            "console.log(JSON.stringify(Gaming.gameServerSizeCommand("
            '[{serverType:"container",name:"vember-minecraft"},'
            '{serverType:"steam",name:"CS2",installdir:"/mnt/games/cs2"}])))'
        )
        assert cmd[:3] == ["sh", "-c", cmd[2]]
        assert cmd[2].startswith("while [ $# -ge 3 ]")
        assert cmd[3] == "sh"
        assert cmd[4:7] == ["vember-minecraft", "container", ""]
        assert cmd[7:10] == ["CS2", "steam", "/mnt/games/cs2"]
        # Names and paths are positional args, never spliced into shell text.
        assert "vember-minecraft" not in cmd[2]
        assert "/mnt/games/cs2" not in cmd[2]
        # Both figures come from one process.
        assert "du -sh" in cmd[2] and "docker ps -a -s" in cmd[2]
        assert "/data" in cmd[2]
        assert "du -sb" in cmd[2], "the bar needs raw bytes, not just a label"

    def test_size_command_skips_blank_names(self, js):
        cmd = js(
            "console.log(JSON.stringify(Gaming.gameServerSizeCommand("
            '[{serverType:"container",name:"  "},null])))'
        )
        assert len(cmd) == 4 and cmd[3] == "sh"

    def test_size_parser_reads_both_figures_and_skips_junk(self, js):
        text = (
            "vember-minecraft\t/mnt/games/MinecraftServer\t225M\t135kB (virtual 982MB)\t235929600\n"
            "CS2\t/mnt/games/cs2\t18G\t-\t19327352832\n"
            "malformed\n"
            "\t/path\t1G\t2G\n"
            "legacy\t/old\t1M\t2M\n"
        )
        out = js(
            "console.log(JSON.stringify(Gaming.parseGameServerSizes("
            + json.dumps(text) + ")))"
        )
        assert len(out) == 3
        assert out[0] == {
            "name": "vember-minecraft", "path": "/mnt/games/MinecraftServer",
            "dataSize": "225M", "containerSize": "135kB (virtual 982MB)",
            "dataBytes": 235929600,
        }
        assert out[1]["containerSize"] == "-"
        assert out[1]["dataBytes"] == 19327352832
        assert out[2]["dataBytes"] == 0, "a four-column legacy row still parses"

    def test_size_command_round_trips_through_stubbed_tools(self, js, tmp_path, monkeypatch):
        bindir = tmp_path / "bin"
        bindir.mkdir()
        data = tmp_path / "data"
        data.mkdir()
        docker = bindir / "docker"
        docker.write_text(
            "#!/bin/sh\n"
            'if [ "$1" = inspect ]; then echo ' + str(data) + '; exit 0; fi\n'
            'if [ "$1" = ps ]; then echo "10kB (virtual 500MB)"; exit 0; fi\n'
            "exit 1\n"
        )
        docker.chmod(0o755)
        du = bindir / "du"
        du.write_text(
            "#!/bin/sh\n"
            'if [ "$1" = "-sb" ]; then printf "44040192\\t%s\\n" "$2"; exit 0; fi\n'
            'printf "42M\\t%s\\n" "$2"\n'
        )
        du.chmod(0o755)
        monkeypatch.setenv("PATH", str(bindir) + ":/usr/bin:/bin")

        cmd = js(
            "console.log(JSON.stringify(Gaming.gameServerSizeCommand("
            '[{serverType:"container",name:"vember-minecraft"}])))'
        )
        result = subprocess.run(cmd, capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        parsed = js(
            "console.log(JSON.stringify(Gaming.parseGameServerSizes("
            + json.dumps(result.stdout) + ")))"
        )
        assert parsed == [{
            "name": "vember-minecraft", "path": str(data),
            "dataSize": "42M", "containerSize": "10kB (virtual 500MB)",
            "dataBytes": 44040192,
        }]


    def test_total_bytes_sums_servers_and_ignores_junk(self, js):
        out = js(
            "console.log(JSON.stringify(Gaming.gameServerTotalBytes("
            '[{dataBytes:100},{dataBytes:"200"},{dataBytes:-5},{dataBytes:"junk"},'
            "{},null])))"
        )
        assert out == 300
        assert js("console.log(JSON.stringify(Gaming.gameServerTotalBytes(null)))") == 0


class TestMinecraftClientLaunch:
    """Two clean Prism instances: join-on-launch and plain main menu."""

    def test_join_command_uses_the_join_instance(self, js):
        cmd = js('console.log(JSON.stringify(Gaming.minecraftClientLaunchCommand("server")))')
        assert cmd == ["prismlauncher", "--launch", "minecraft-join"]

    def test_vanilla_command_uses_the_plain_instance(self, js):
        cmd = js('console.log(JSON.stringify(Gaming.minecraftClientLaunchCommand("vanilla")))')
        assert cmd == ["prismlauncher", "--launch", "minecraft-vanilla"]
        assert "--server" not in cmd

    def test_unknown_mode_falls_back_to_plain_launch(self, js):
        for mode in ("", "bogus"):
            cmd = js("console.log(JSON.stringify(Gaming.minecraftClientLaunchCommand("
                     + __import__("json").dumps(mode) + ")))")
            assert cmd == ["prismlauncher", "--launch", "minecraft-vanilla"]

    def test_installed_detection(self, js):
        apps = [{"id": "steam", "installed": True},
                {"id": "prismlauncher", "installed": False}]
        assert js("console.log(JSON.stringify(Gaming.minecraftClientInstalled("
                  + __import__("json").dumps(apps) + ")))") is False
        apps[1]["installed"] = True
        assert js("console.log(JSON.stringify(Gaming.minecraftClientInstalled("
                  + __import__("json").dumps(apps) + ")))") is True
        assert js("console.log(JSON.stringify(Gaming.minecraftClientInstalled(null)))") is False


class TestMinecraftServerList:
    """The hub keeps one visible server entry in Prism's multiplayer list."""

    @staticmethod
    def _nbt(data):
        pos = 0

        def u1():
            nonlocal pos
            value = data[pos]
            pos += 1
            return value

        def u2():
            nonlocal pos
            value = int.from_bytes(data[pos:pos + 2], "big")
            pos += 2
            return value

        def u4():
            nonlocal pos
            value = int.from_bytes(data[pos:pos + 4], "big")
            pos += 4
            return value

        def string():
            nonlocal pos
            length = u2()
            value = data[pos:pos + length].decode("utf-8")
            pos += length
            return value

        def payload(tag):
            if tag == 1:
                return u1()
            if tag == 8:
                return string()
            if tag == 9:
                item_type = u1()
                return [payload(item_type) for _ in range(u4())]
            if tag == 10:
                out = {}
                while True:
                    child = u1()
                    if child == 0:
                        return out
                    name = string()
                    out[name] = payload(child)
            raise AssertionError("unexpected tag " + str(tag))

        assert u1() == 10  # root compound
        assert string() == ""
        return payload(10)

    def test_generated_entry_is_visible(self, js):
        data = bytes(js(
            'console.log(JSON.stringify(Gaming.minecraftServerListBytes('
            '"vemberos:25565", "Vember OS")))'
        ))
        servers = self._nbt(data)["servers"]
        assert servers == [{"hidden": 0, "ip": "vemberos:25565", "name": "Vember OS"}]

    def test_command_writes_a_real_file(self, js, tmp_path):
        cmd = js(
            'console.log(JSON.stringify(Gaming.minecraftServerListCommand('
            + __import__("json").dumps(str(tmp_path / "join")) + ', "mc.local:25565", "My Server")))'
        )
        assert cmd[0] == "sh" and cmd[1] == "-c"
        (tmp_path / "join").mkdir()
        assert subprocess.run(cmd, capture_output=True, text=True).returncode == 0
        data = (tmp_path / "join" / "servers.dat").read_bytes()
        assert self._nbt(data)["servers"][0]["ip"] == "mc.local:25565"
        assert self._nbt(data)["servers"][0]["hidden"] == 0

    def test_command_skips_layouts_that_are_not_installed(self, js, tmp_path):
        missing = tmp_path / "not-installed"
        cmd = js(
            'console.log(JSON.stringify(Gaming.minecraftServerListCommand('
            + __import__("json").dumps(str(missing)) + ', "mc:25565", "Name")))'
        )
        assert subprocess.run(cmd, capture_output=True, text=True).returncode == 0
        assert not missing.exists()

    def test_command_rejects_relative_paths(self, js):
        cmd = js(
            'console.log(JSON.stringify(Gaming.minecraftServerListCommand('
            '"relative/path", "mc:25565", "Name")))'
        )
        assert cmd == ["sh", "-c", "exit 1"]

    def test_join_dirs_cover_both_prism_layouts(self, js):
        dirs = js(
            'console.log(JSON.stringify(Gaming.minecraftJoinGameDirs("/home/someone")))'
        )
        assert "/home/someone/.local/share/PrismLauncher/instances/minecraft-join/minecraft" in dirs
        assert "/home/someone/.local/share/PrismLauncher/instances/minecraft-vanilla/minecraft" in dirs
        assert any(".var/app/org.prismlauncher.PrismLauncher" in d for d in dirs)


class TestOneClickLaunch:
    """Each created server gets its own Prism auto-join instance."""

    @staticmethod
    def _template(home, instance_id="minecraft-server"):
        root = home / ".local/share/PrismLauncher/instances" / instance_id
        (root / "minecraft" / "mods").mkdir(parents=True)
        (root / "minecraft" / "mods" / "controlify.jar").write_text("jar")
        (root / "mmc-pack.json").write_text('{"components":[],"formatVersion":1}')
        (root / "instance.cfg").write_text(
            "[General]\nname=Template\nJoinServerOnLaunch=false\n"
            "JoinServerOnLaunchAddress=old:1\nlastLaunchTime=123\nuuid=abc\n\n[UI]\nfoo=bar\n")
        return root

    def _prepare(self, js, home, name, address, source=""):
        cmd = js("console.log(JSON.stringify(Gaming.minecraftServerInstanceCommand("
                 + __import__("json").dumps({
                     "homeDir": str(home), "id": js(
                         'console.log(JSON.stringify(Gaming.minecraftInstanceId('
                         + __import__("json").dumps(name) + ')))'),
                     "name": name, "address": address, "sourceId": source
                 }) + ")))")
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        assert run.returncode == 0, run.stderr
        return Path(run.stdout.strip())

    def test_instance_id_is_stable_and_reserves_hub_instances(self, js):
        assert js('console.log(JSON.stringify(Gaming.minecraftInstanceId("My Cool Server!")))') == "my-cool-server"
        for reserved in ("minecraft-server", "minecraft-join", "minecraft-vanilla",
                         "vemberos-server", "vemberos-vanilla"):
            assert js("console.log(JSON.stringify(Gaming.minecraftInstanceId("
                      + __import__("json").dumps(reserved) + ")))") == "server-" + reserved
        assert js('console.log(JSON.stringify(Gaming.minecraftInstanceId("  ")))') == "vember-server"

    def test_unsafe_inputs_are_rejected(self, js):
        for opts in (
            {"homeDir": "relative", "id": "ok", "name": "S", "address": "h:1"},
            {"homeDir": "/tmp/h", "id": "../escape", "name": "S", "address": "h:1"},
            {"homeDir": "/tmp/h", "id": "ok", "name": "", "address": "h:1"},
            {"homeDir": "/tmp/h", "id": "ok", "name": "S", "address": "h\ninjected=1"},
        ):
            cmd = js("console.log(JSON.stringify(Gaming.minecraftServerInstanceCommand("
                     + __import__("json").dumps(opts) + ")))")
            assert cmd == ["sh", "-c", "exit 1"]

    def test_prepare_writes_a_working_join_instance(self, js, tmp_path):
        template = self._template(tmp_path)
        dst = self._prepare(js, tmp_path, "Second Server", "localhost:25566")
        cfg = (dst / "instance.cfg").read_text()
        assert "name=Second Server" in cfg
        assert "JoinServerOnLaunch=true" in cfg
        assert "JoinServerOnLaunchAddress=localhost:25566" in cfg
        assert "uuid=" not in cfg and "lastLaunchTime=" not in cfg
        assert "[UI]" in cfg and "foo=bar" in cfg
        assert (dst / "mmc-pack.json").exists()
        assert (dst / "minecraft/mods/controlify.jar").exists()
        expected = bytes(js('console.log(JSON.stringify(Gaming.minecraftServerListBytes('
                            '"localhost:25566", "Second Server")))'))
        assert (dst / "minecraft/servers.dat").read_bytes() == expected
        meta = json.loads((dst / "vember-hub.json").read_text())
        assert meta == {"container": "Second Server", "sourceId": "minecraft-server",
                        "address": "localhost:25566", "client": "prism"}
        assert template.exists()

    def test_prepare_is_idempotent_and_keeps_the_source(self, js, tmp_path):
        self._template(tmp_path)
        self._prepare(js, tmp_path, "Second Server", "localhost:25566", "CreateVerse")
        dst = self._prepare(js, tmp_path, "Second Server", "localhost:25567")
        assert "JoinServerOnLaunchAddress=localhost:25567" in (dst / "instance.cfg").read_text()
        assert json.loads((dst / "vember-hub.json").read_text())["sourceId"] == "CreateVerse"

    @staticmethod
    def _varint(n):
        out = b""
        while True:
            b = n & 0x7F
            n >>= 7
            out += bytes([b | (0x80 if n else 0)])
            if not n:
                return out

    @classmethod
    def _answer_status(cls, conn):
        """Answer a Minecraft status handshake with a minimal valid JSON reply."""
        conn.settimeout(5)
        data = conn.recv(4096)
        if not data:
            return
        payload = json.dumps({"description": "Fake Server"}).encode()
        body = cls._varint(0) + cls._varint(len(payload)) + payload
        conn.sendall(cls._varint(len(body)) + body)

    def test_wait_command_rejects_invalid_port(self, js):
        cmd = js("console.log(JSON.stringify(Gaming.minecraftPortWaitCommand(0, 2)))")
        assert cmd == ["sh", "-c", "exit 1"]

    def test_wait_command_requires_a_real_minecraft_status_reply(self, js):
        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        port = server.getsockname()[1]
        thread = None
        try:
            import threading
            thread = threading.Thread(
                target=lambda: self._answer_status(server.accept()[0]), daemon=True)
            thread.start()
            cmd = js("console.log(JSON.stringify(Gaming.minecraftPortWaitCommand("
                     + str(port) + ", 5)))")
            run = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
            assert run.stdout.strip() == "ready", run.stdout
        finally:
            server.close()

    def test_wait_command_ignores_a_bare_proxy_socket(self, js):
        # A dead game server behind Docker's published-port proxy still accepts
        # TCP. A plain listener must NOT count as ready, or Prism opens to a
        # refused connection -- the exact failure this ping fixes.
        server = socket.socket()
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        port = server.getsockname()[1]
        try:
            cmd = js("console.log(JSON.stringify(Gaming.minecraftPortWaitCommand("
                     + str(port) + ", 2)))")
            run = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            assert run.stdout.strip() == "timeout", run.stdout
        finally:
            server.close()


class TestTotalInstalledGameCount:
    def test_sums_every_library(self, js):
        opts = {"steam": 83, "bnet": 3, "prism": 5, "heroic": 2, "minecraft": 3}
        cmd = js("console.log(JSON.stringify(Gaming.totalInstalledGameCount("
                 + __import__("json").dumps(opts) + ")))")
        assert cmd == 96

    def test_skips_unavailable_and_missing(self, js):
        opts = {"steam": 4, "bnet": -1, "minecraft": "nope"}
        cmd = js("console.log(JSON.stringify(Gaming.totalInstalledGameCount("
                 + __import__("json").dumps(opts) + ")))")
        assert cmd == 4

    def test_empty_input_is_zero(self, js):
        assert js("console.log(Gaming.totalInstalledGameCount())") == 0


class TestMinecraftTemplateAndClients:
    """Hub-owned template, keybinding clones and per-server client choice."""

    @staticmethod
    def _run(cmd):
        return subprocess.run(cmd, capture_output=True, text=True, timeout=60)

    @staticmethod
    def _setup_cmd(js, home, seed=""):
        return js("console.log(JSON.stringify(Gaming.minecraftPrismSetupCommand("
                  + json.dumps(str(home)) + ", " + json.dumps(str(seed)) + ")))")

    def test_setup_seeds_template_and_two_keybinding_clones(self, js, tmp_path):
        root = tmp_path / ".local/share/PrismLauncher/instances"
        seed = tmp_path / "seed"
        (seed / "minecraft" / "mods").mkdir(parents=True)
        (seed / "minecraft" / "mods" / "controlify.jar").write_text("jar")
        (seed / "instance.cfg").write_text("[General]\nname=Old\n")
        (seed / "mmc-pack.json").write_text('{"components":[],"formatVersion":1}')
        cmd = self._setup_cmd(js, tmp_path, seed)
        run = self._run(cmd)
        assert run.returncode == 0, run.stderr
        assert run.stdout.strip() == "minecraft-server,minecraft-join,minecraft-vanilla"
        for iid in ("minecraft-server", "minecraft-join", "minecraft-vanilla"):
            assert (root / iid / "instance.cfg").is_file()
        assert "name=Vember Minecraft Template" in (
            root / "minecraft-server" / "instance.cfg").read_text()
        join_cfg = (root / "minecraft-join" / "instance.cfg").read_text()
        assert "JoinServerOnLaunch=true" in join_cfg
        assert "JoinServerOnLaunchAddress=vemberos:25565" in join_cfg
        assert "JoinServerOnLaunch" not in (
            root / "minecraft-vanilla" / "instance.cfg").read_text()
        assert (root / "minecraft-join" / "minecraft" / "mods" / "controlify.jar").exists()
        again = self._run(cmd)
        assert again.returncode == 0 and again.stdout.strip() == "ready"

    def test_setup_without_seed_builds_a_usable_template(self, js, tmp_path):
        run = self._run(self._setup_cmd(js, tmp_path))
        assert run.returncode == 0, run.stderr
        root = tmp_path / ".local/share/PrismLauncher/instances"
        pack = json.loads((root / "minecraft-server" / "mmc-pack.json").read_text())
        versions = [c["version"] for c in pack["components"]
                    if c["uid"] == "net.minecraft"]
        assert versions == ["26.3"]

    def test_setup_rejects_relative_paths(self, js):
        assert self._setup_cmd(js, "relative/home") == ["sh", "-c", "exit 1"]
        assert self._setup_cmd(js, "/tmp/home", "relative/seed") == [
            "sh", "-c", "exit 1"]

    def test_client_defaults_are_read_from_sidecars(self, js, tmp_path):
        root = tmp_path / ".local/share/PrismLauncher/instances"
        for name, client in (("One", "prism"), ("Two", "official")):
            instance = root / name
            instance.mkdir(parents=True)
            (instance / "vember-hub.json").write_text(
                json.dumps({"container": name, "client": client}))
        cmd = js("console.log(JSON.stringify(Gaming.minecraftClientDefaultsCommand("
                 + json.dumps(str(tmp_path)) + ")))")
        run = self._run(cmd)
        assert run.returncode == 0, run.stderr
        parsed = js("console.log(JSON.stringify(Gaming.parseMinecraftClientDefaults("
                    + json.dumps(run.stdout) + ")))")
        assert parsed == {"One": "prism", "Two": "official"}

    def test_official_list_merges_and_is_idempotent(self, js, tmp_path):
        def add(addr, name):
            cmd = js("console.log(JSON.stringify(Gaming.minecraftOfficialServerListCommand("
                     + json.dumps(str(tmp_path)) + ", " + json.dumps(addr) + ", "
                     + json.dumps(name) + ")))")
            run = self._run(cmd)
            assert run.returncode == 0, run.stderr
            return run

        add("vemberos:25565", "First")
        add("vemberos:25566", "Second")
        again = add("vemberos:25566", "Second")
        assert again.stdout.strip() == "2"
        raw = (tmp_path / ".minecraft" / "servers.dat").read_bytes()
        assert b"vemberos:25565" in raw and b"First" in raw
        assert b"vemberos:25566" in raw and b"Second" in raw
        assert struct.unpack_from(">i", raw, 14)[0] == 2

    def test_official_launch_uses_the_installed_launcher(self, js):
        cmd = js("console.log(JSON.stringify(Gaming.minecraftOfficialLaunchCommand()))")
        assert cmd[:2] == ["sh", "-c"]
        assert "minecraft-launcher" in cmd[2]
        assert "flatpak" in cmd[2]

    def test_instance_sidecar_records_the_official_choice(self, js, tmp_path):
        template = tmp_path / ".local/share/PrismLauncher/instances" / "minecraft-server"
        template.mkdir(parents=True)
        (template / "instance.cfg").write_text("[General]\nname=Template\n")
        opts = {"homeDir": str(tmp_path), "id": "official-server", "name": "Official",
                "address": "vemberos:25590", "client": "official"}
        cmd = js("console.log(JSON.stringify(Gaming.minecraftServerInstanceCommand("
                 + json.dumps(opts) + ")))")
        run = self._run(cmd)
        assert run.returncode == 0, run.stderr
        sidecar = tmp_path / ".local/share/PrismLauncher/instances" / "official-server" / "vember-hub.json"
        assert json.loads(sidecar.read_text())["client"] == "official"
