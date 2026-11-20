"""Guided Minecraft server wizard: option lists, client detection and wiring."""

import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def read(rel):
    return (REPO / rel).read_text()


class TestWizardOptions:
    def test_client_choice_comes_first_and_offers_both_launchers(self, js):
        opts = js("console.log(JSON.stringify(MinecraftWizard.clientOptions()))")
        assert [o["value"] for o in opts] == ["prism", "official"]
        assert all(o["label"] and o["detail"] for o in opts)

    def test_difficulty_ram_and_version_are_pick_lists(self, js):
        diff = js("console.log(JSON.stringify(MinecraftWizard.difficultyOptions()))")
        assert [o["value"] for o in diff] == ["PEACEFUL", "EASY", "NORMAL", "HARD"]
        mem = js("console.log(JSON.stringify(MinecraftWizard.memoryOptions()))")
        assert "4G" in [o["value"] for o in mem]
        assert len(mem) >= 4
        versions = js("console.log(JSON.stringify(MinecraftWizard.versionOptions()))")
        assert versions[0]["value"] == "LATEST"
        assert len(versions) >= 4
        types = js("console.log(JSON.stringify(MinecraftWizard.serverTypeOptions()))")
        assert {o["value"] for o in types} == {"PAPER", "VANILLA", "FORGE", "FABRIC"}

    def test_runtime_choice_offers_docker_and_manual(self, js):
        opts = js("console.log(JSON.stringify(MinecraftWizard.runModeOptions()))")
        assert [o["value"] for o in opts] == ["docker", "manual"]


class TestClientDetectionAndInstall:
    def test_check_command_reports_both_clients_as_tabs(self, js):
        cmd = js("console.log(JSON.stringify(MinecraftWizard.clientCheckCommand()))")
        assert cmd[0] == "sh" and cmd[1] == "-c"
        assert "prismlauncher" in cmd[2] and "minecraft-launcher" in cmd[2]
        result = subprocess.run(["sh", "-n"], input=cmd[2], capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
        run = subprocess.run(cmd, capture_output=True, text=True)
        assert run.returncode == 0, run.stderr
        rows = dict(line.split("\t") for line in run.stdout.strip().splitlines())
        assert set(rows) == {"prism", "official"}
        assert set(rows.values()) <= {"0", "1"}

    def test_parse_scan_is_defensive(self, js):
        out = js(
            'console.log(JSON.stringify(MinecraftWizard.parseClientScan('
            "'prism\\t1\\nofficial\\t0\\njunk\\t1\\n')))"
        )
        assert out == {"prism": True, "official": False}

    def test_install_commands_are_valid_shell(self, js):
        for client in ("prism", "official"):
            cmd = js(
                'console.log(JSON.stringify(MinecraftWizard.clientInstallCommand('
                '"{0}")))'.format(client)
            )
            assert cmd[0] == "sh" and cmd[1] == "-c"
            result = subprocess.run(["sh", "-n"], input=cmd[2], capture_output=True, text=True)
            assert result.returncode == 0, (client, result.stderr)
        prism = js('console.log(JSON.stringify(MinecraftWizard.clientInstallCommand("prism")))')
        official = js('console.log(JSON.stringify(MinecraftWizard.clientInstallCommand("official")))')
        assert "prismlauncher" in prism[2]
        assert "minecraft-launcher" in official[2]

    def test_client_name_is_human_readable(self, js):
        assert js('console.log(JSON.stringify(MinecraftWizard.clientName("prism")))') == \
            "Prism Launcher"
        assert js('console.log(JSON.stringify(MinecraftWizard.clientName("official")))') == \
            "Official Minecraft Launcher"


class TestWizardWiring:
    def test_panel_owns_wizard_state_and_preflight(self):
        text = read("Panel.qml")
        for prop in (
            "property bool mcWizardOpen: false",
            "property int mcWizardStep: 1",
            'property string mcWizardClient: "prism"',
            'property string mcWizardRunMode: "docker"',
            "property bool mcWizardImageReady: false",
            "property real mcWizardPullPercent: -1",
        ):
            assert prop in text, prop + " is missing from the wizard state"
        for fn in (
            "function openMinecraftServerWizard()",
            "function closeMinecraftServerWizard()",
            "function mcWizardInstallClient()",
            "function mcWizardPullImage()",
            "function mcWizardCreate()",
            "function mcWizardCommandPreview()",
        ):
            assert fn in text, fn + " is missing"
        for proc in (
            "id: mcWizardClientCheckProc", "id: mcWizardInstallProc",
            "id: mcWizardDockerCheckProc", "id: mcWizardImageCheckProc",
            "id: mcWizardPullProc", "id: mcWizardInstallPollTimer",
        ):
            assert proc in text, proc + " is missing"
        assert 'import "model/MinecraftWizard.mjs" as Wizard' in text

    def test_modal_is_instantiated_once(self):
        text = read("HubPanel.qml")
        assert "MinecraftServerWizard { panel: panel; cardRadius: card.radius }" in text


class TestModpackRecipes:
    def _scan(self, js, home):
        cmd = js('console.log(JSON.stringify(MinecraftWizard.modpackScanCommand('
                 + __import__("json").dumps(str(home)) + ')))')
        assert cmd[0] == "python3" and cmd[1] == "-c"
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        assert run.returncode == 0, run.stderr
        return js('console.log(JSON.stringify(MinecraftWizard.parseModpackScan('
                  + __import__("json").dumps(run.stdout) + ')))')

    def test_installed_modpacks_become_complete_recipes(self, js, tmp_path):
        root = tmp_path / ".local/share/PrismLauncher/instances/MyPack"
        game = root / "minecraft"
        (game / "mods").mkdir(parents=True)
        (game / "mods" / "jei.jar").write_text("jar")
        (game / "saves" / "My World").mkdir(parents=True)
        (game / "saves" / "My World" / "level.dat").write_text("nbt")
        (root / "instance.cfg").write_text("name=My Pack: The Modpack\n")
        (root / "mmc-pack.json").write_text(__import__("json").dumps({
            "components": [
                {"uid": "net.minecraft", "version": "1.20.1"},
                {"uid": "net.minecraftforge", "version": "47.4.28"},
            ]
        }))

        packs = self._scan(js, tmp_path)
        assert len(packs) == 1
        pack = packs[0]
        assert pack["name"] == "My Pack: The Modpack"
        assert pack["loader"] == "FORGE"
        assert pack["version"] == "1.20.1-47.4.28"
        assert pack["modsDir"] == str(game / "mods")
        assert pack["worldDir"] == str(game / "saves" / "My World")

        options = js('console.log(JSON.stringify(MinecraftWizard.modpackOptions('
                     + __import__("json").dumps(packs) + ')))')
        assert options[0]["value"] == ""
        assert options[1]["value"] == "MyPack"
        assert "FORGE" in options[1]["label"]

    def test_fabric_pack_without_a_world_is_still_offered(self, js, tmp_path):
        root = tmp_path / ".local/share/PrismLauncher/instances/FabPack"
        mods = root / "minecraft" / "mods"
        mods.mkdir(parents=True)
        (root / "instance.cfg").write_text("name=Fab Pack\n")
        (root / "mmc-pack.json").write_text(__import__("json").dumps({
            "components": [
                {"uid": "net.minecraft", "version": "1.20.1"},
                {"uid": "net.fabricmc.fabric-loader", "version": "0.20.1"},
            ]
        }))
        packs = self._scan(js, tmp_path)
        assert len(packs) == 1
        assert packs[0]["loader"] == "FABRIC"
        assert packs[0]["version"] == "1.20.1"
        assert packs[0]["worldDir"] == ""

    def test_parse_ignores_garbage(self, js):
        assert js('console.log(JSON.stringify(MinecraftWizard.parseModpackScan('
                  '"\\njunk\\ta\\tb\\tVANILLA\\tx\\ty\\n")))') == []

    def test_hub_join_instances_are_not_offered_as_modpacks(self, js):
        raw = ("vemberos-server\tVemberOS Server\tFABRIC\t26.3\t/mods\t\n"
               "CreateVerse\tCreateVerse\tFORGE\t1.20.1-47.4.28\t/mods\t/world")
        packs = js('console.log(JSON.stringify(MinecraftWizard.parseModpackScan('
                   + __import__("json").dumps(raw) + ')))')
        assert [p["id"] for p in packs] == ["CreateVerse"]
