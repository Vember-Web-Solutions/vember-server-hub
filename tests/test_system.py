"""Tests for model/Systemd.mjs, SystemInfo.mjs and Omarchy.mjs."""



class TestSystemd:
    def test_query_commands_are_argv_arrays(self, js):
        out = js(
            "console.log(JSON.stringify(["
            'Systemd.isActiveCommand("docker"), Systemd.isEnabledCommand("docker")]))'
        )
        assert out[0] == ["systemctl", "is-active", "docker"]
        assert out[1] == ["systemctl", "is-enabled", "docker"]

    def test_privileged_action_goes_through_pkexec(self, js):
        out = js('console.log(JSON.stringify(Systemd.pkexecCommand("restart", "docker")))')
        assert out == ["pkexec", "systemctl", "restart", "docker"]

    def test_interactive_action_uses_an_omarchy_terminal(self, js):
        out = js('console.log(JSON.stringify(Systemd.terminalCommand("restart", "docker")))')
        assert out[:3] == ["omarchy", "launch", "terminal"]
        assert out[-2:] == ["restart", "docker"]

    def test_unit_name_is_stringified(self, js):
        out = js("console.log(JSON.stringify(Systemd.isActiveCommand(42)))")
        assert out == ["systemctl", "is-active", "42"]


class TestSystemInfo:
    def test_findmnt_requests_the_fields_the_ui_shows(self, js):
        out = js('console.log(JSON.stringify(SystemInfo.findmntCommand("/mnt/games")))')
        assert out[0] == "findmnt"
        assert "SOURCE,TARGET,FSTYPE,LABEL,SIZE,USED,AVAIL,USE%" in out
        assert out[-1] == "/mnt/games"

    def test_df_uses_byte_units_for_exact_maths(self, js):
        out = js('console.log(JSON.stringify(SystemInfo.dfBytesCommand("/mnt/games")))')
        assert out[:3] == ["df", "-B1", "-P"]
        assert out[-1] == "/mnt/games"

    def test_pgrep_matches_exact_process_names(self, js):
        out = js('console.log(JSON.stringify(SystemInfo.pgrepExactCommand("steam")))')
        assert out == ["pgrep", "-x", "steam"]

    def test_findmnt_line_is_parsed_into_fields(self, js):
        out = js(
            'console.log(JSON.stringify(SystemInfo.parseFindmnt('
            '"/dev/sda1 /mnt/games ext4 GAMES 2T 1T 1T 50%")))'
        )
        assert out == {
            "source": "/dev/sda1",
            "target": "/mnt/games",
            "fstype": "ext4",
            "label": "GAMES",
            "size": "2T",
            "used": "1T",
            "avail": "1T",
            "usePercent": "50%",
        }

    def test_findmnt_empty_input_is_null(self, js):
        assert js('console.log(JSON.stringify(SystemInfo.parseFindmnt("")))') is None

    def test_findmnt_missing_columns_do_not_crash(self, js):
        out = js('console.log(JSON.stringify(SystemInfo.parseFindmnt("/dev/sda1")))')
        assert out["source"] == "/dev/sda1"
        assert out["fstype"] == ""

    def test_df_skips_the_header_and_reads_numbers(self, js):
        out = js(
            'console.log(JSON.stringify(SystemInfo.parseDfBytes('
            '"Filesystem 1B-blocks Used Available Use% Mounted\\n'
            '/dev/sda1 1000 400 600 40% /mnt/games")))'
        )
        assert out == {
            "filesystem": "/dev/sda1",
            "totalBytes": 1000,
            "usedBytes": 400,
            "availBytes": 600,
            "usePercent": "40%",
            "target": "/mnt/games",
        }

    def test_df_header_only_is_null(self, js):
        out = js(
            'console.log(JSON.stringify(SystemInfo.parseDfBytes('
            '"Filesystem 1B-blocks Used Available Use% Mounted")))'
        )
        assert out is None

    def test_pgrep_count_counts_lines(self, js):
        assert js('console.log(JSON.stringify(SystemInfo.parsePgrepCount("1\\n2\\n3\\n")))') == 3

    def test_pgrep_count_of_nothing_is_zero(self, js):
        assert js('console.log(JSON.stringify(SystemInfo.parsePgrepCount("")))') == 0


class TestOmarchy:
    def test_update_runs_in_a_presentation_terminal(self, js):
        out = js("console.log(JSON.stringify(Omarchy.updateTerminalCommand()))")
        assert out[0] == "/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation"
        assert out[1] == "/usr/share/omarchy/bin/omarchy-update"

    def test_both_paths_exist_on_this_machine(self, js):
        # Only meaningful on an Omarchy install; CI runners have neither path.
        import os

        out = js("console.log(JSON.stringify(Omarchy.updateTerminalCommand()))")
        missing = [p for p in out if not os.access(p, os.X_OK)]
        if missing:
            import pytest

            pytest.skip("not an Omarchy install: " + ", ".join(missing))
        assert not missing


class TestStorageUseColor:
    """Storage pressure thresholds. These are the values that rot silently."""

    def test_comfortable_is_green(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "SystemInfo.storageUseColor(0), SystemInfo.storageUseColor(0.5),"
            "SystemInfo.storageUseColor(0.749)]))"
        )
        assert out == ["#22c55e"] * 3

    def test_seventy_five_percent_is_amber(self, js):
        assert js("console.log(JSON.stringify(SystemInfo.storageUseColor(0.75)))") == "#eab308"

    def test_eighty_nine_percent_is_still_amber(self, js):
        assert js("console.log(JSON.stringify(SystemInfo.storageUseColor(0.899)))") == "#eab308"

    def test_ninety_percent_is_red(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "SystemInfo.storageUseColor(0.9), SystemInfo.storageUseColor(1)]))"
        )
        assert out == ["#ef4444"] * 2

    def test_missing_ratio_reads_as_empty(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "SystemInfo.storageUseColor(null), SystemInfo.storageUseColor(undefined),"
            "SystemInfo.storageUseColor('nope')]))"
        )
        assert out == ["#22c55e"] * 3
