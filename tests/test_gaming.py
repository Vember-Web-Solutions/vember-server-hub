"""Tests for model/Gaming.mjs: catalog, Steam and Battle.net helpers."""

import json
import subprocess


class TestCatalog:
    def test_every_entry_has_the_fields_the_ui_needs(self, js):
        out = js("console.log(JSON.stringify(Gaming.catalog()))")
        assert len(out) >= 6
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
            "status": "up",
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
        assert cmd == ["prismlauncher", "--launch", "vemberos-server"]

    def test_vanilla_command_uses_the_plain_instance(self, js):
        cmd = js('console.log(JSON.stringify(Gaming.minecraftClientLaunchCommand("vanilla")))')
        assert cmd == ["prismlauncher", "--launch", "vemberos-vanilla"]
        assert "--server" not in cmd

    def test_unknown_mode_falls_back_to_plain_launch(self, js):
        for mode in ("", "bogus"):
            cmd = js("console.log(JSON.stringify(Gaming.minecraftClientLaunchCommand("
                     + __import__("json").dumps(mode) + ")))")
            assert cmd == ["prismlauncher", "--launch", "vemberos-vanilla"]

    def test_installed_detection(self, js):
        apps = [{"id": "steam", "installed": True},
                {"id": "prismlauncher", "installed": False}]
        assert js("console.log(JSON.stringify(Gaming.minecraftClientInstalled("
                  + __import__("json").dumps(apps) + ")))") is False
        apps[1]["installed"] = True
        assert js("console.log(JSON.stringify(Gaming.minecraftClientInstalled("
                  + __import__("json").dumps(apps) + ")))") is True
        assert js("console.log(JSON.stringify(Gaming.minecraftClientInstalled(null)))") is False
