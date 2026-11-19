"""Tests for model/Gaming.mjs: catalog, Steam and Battle.net helpers."""

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
