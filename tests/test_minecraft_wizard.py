"""Guided Minecraft server wizard: option lists, client detection and wiring."""

import json
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
        plain = js("console.log(JSON.stringify(MinecraftWizard.memoryOptions(false)))")
        modded = js("console.log(JSON.stringify(MinecraftWizard.memoryOptions(true)))")
        assert [o["value"] for o in plain] == ["2G", "4G", "6G", "8G"]
        assert [o["value"] for o in modded] == ["3G", "5G", "7G", "9G"]
        assert not set(o["value"] for o in plain) & set(o["value"] for o in modded)

    def test_memory_parity_is_derived_from_loader(self, js):
        for t in ("FORGE", "FABRIC", "fabric"):
            assert js("console.log(JSON.stringify(MinecraftWizard.isModdedType(" + json.dumps(t) + ")))") is True
        for t in ("PAPER", "VANILLA", ""):
            assert js("console.log(JSON.stringify(MinecraftWizard.isModdedType(" + json.dumps(t) + ")))") is False

    def test_nearest_memory_snaps_onto_correct_parity(self, js):
        for value, modded, expected in (
            ("4G", True, "5G"), ("6G", True, "7G"), ("6G", False, "6G"),
            ("7G", False, "8G"), ("3G", False, "4G"), ("12G", False, "8G"),
        ):
            call = "MinecraftWizard.nearestMemory(" + json.dumps(value) + "," + json.dumps(modded) + ")"
            assert js("console.log(JSON.stringify(" + call + "))") == expected
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
        assert pack["supportDir"] == str(game)

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
        raw = ("minecraft-server\tVember Minecraft Template\tFABRIC\t26.3\t/mods\t\n"
               "minecraft-join\tVemberOS Server\tFABRIC\t26.3\t/mods\t\n"
               "minecraft-vanilla\tPlain Vanilla\tFABRIC\t26.3\t/mods\t\n"
               "vemberos-server\tVemberOS Server\tFABRIC\t26.3\t/mods\t\n"
               "CreateVerse\tCreateVerse\tFORGE\t1.20.1-47.4.28\t/mods\t/world")
        packs = js('console.log(JSON.stringify(MinecraftWizard.parseModpackScan('
                   + __import__("json").dumps(raw) + ')))')
        assert [p["id"] for p in packs] == ["CreateVerse"]


class TestPortPool:
    """New servers get the first free port instead of a colliding default."""

    @staticmethod
    def _containers(ports, name="vember-minecraft"):
        return [{"name": name, "ports": ports}]

    def test_pool_starts_at_the_default(self, js):
        pool = js("console.log(JSON.stringify(MinecraftWizard.portPool()))")
        assert pool[0] == 25565
        assert pool == list(range(25565, 25585))

    def test_published_docker_ports_reserve_slots(self, js):
        containers = self._containers(
            "0.0.0.0:25565->25565/tcp, [::]:25565->25565/tcp, 5432/tcp")
        used = js("console.log(JSON.stringify(MinecraftWizard.usedContainerPorts("
                  + __import__("json").dumps(containers) + ")))")
        assert used == [25565]

    def test_taken_default_assigns_the_next_free_slot(self, js):
        containers = self._containers(
            "0.0.0.0:25565->25565/tcp, [::]:25565->25565/tcp")
        status = js("console.log(JSON.stringify(MinecraftWizard.portStatus("
                    + __import__("json").dumps(containers) + ', "", 25565)))')
        assert status["port"] == 25566
        assert 25565 not in status["free"]
        assert "by vember-minecraft" in status["note"]
        assert status["options"][0]["value"] == "25566"

    def test_host_listeners_block_a_port_too(self, js):
        status = js("console.log(JSON.stringify(MinecraftWizard.portStatus("
                    '[], "22\\n25566\\n25567\\nnot-a-port", 25565)))')
        assert status["port"] == 25565  # default is free
        assert 25566 not in status["free"]
        status2 = js("console.log(JSON.stringify(MinecraftWizard.portStatus("
                     '[], "25565\\n25566", 25565)))')
        assert status2["port"] == 25567

    def test_an_existing_free_choice_is_kept(self, js):
        containers = self._containers("0.0.0.0:25565->25565/tcp")
        status = js("console.log(JSON.stringify(MinecraftWizard.portStatus("
                    + __import__("json").dumps(containers) + ', "", 25570)))')
        assert status["port"] == 25570
        assert "in use by vember-minecraft" in status["note"]
        assert "assigned" not in status["note"]

    def test_exhausted_pool_is_reported(self, js):
        listeners = "\n".join(str(p) for p in range(25565, 25585))
        status = js("console.log(JSON.stringify(MinecraftWizard.portStatus("
                    '[], ' + __import__("json").dumps(listeners) + ', 25565)))')
        assert status["port"] is None
        assert status["options"] == []
        assert "are in use" in status["note"]

    def test_listener_command_and_parser(self, js):
        cmd = js("console.log(JSON.stringify(MinecraftWizard.listeningPortsCommand()))")
        assert cmd[0] == "python3" and cmd[1] == "-c"
        assert "/proc/net/tcp" in cmd and "/proc/net/tcp6" in cmd
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        assert run.returncode == 0, run.stderr
        ports = js("console.log(JSON.stringify(MinecraftWizard.parseListeningPorts("
                   + __import__("json").dumps(run.stdout) + ")))")
        assert isinstance(ports, list)
        assert all(isinstance(p, int) and 1 <= p <= 65535 for p in ports)


class TestEditPortPool:
    """Editing keeps the server's own port; only other users of a port collide."""

    @staticmethod
    def _status(js, containers, listeners, old, port):
        body = ("console.log(JSON.stringify(MinecraftWizard.editPortStatus("
                + json.dumps(containers) + ", " + json.dumps(listeners) + ", "
                + json.dumps(old) + ", " + str(port) + ")))")
        return js(body)

    def test_own_container_does_not_push_the_edit_off_its_port(self, js):
        containers = [
            {"name": "RPG", "ports": "0.0.0.0:25570->25570/tcp"},
            {"name": "vember-minecraft", "ports": "0.0.0.0:25565->25565/tcp"},
        ]
        # The running server also appears as a host listener on its own port.
        status = self._status(js, containers, "25565\n25570", "RPG", 25570)
        assert status["port"] == 25570
        assert 25570 in status["free"]
        assert "Keeping current port 25570" in status["note"]
        assert any(o["value"] == "25570" and "current" in o["label"]
                   for o in status["options"])

    def test_another_container_still_blocks_a_port(self, js):
        containers = [
            {"name": "RPG", "ports": "0.0.0.0:25570->25570/tcp"},
            {"name": "bigheads", "ports": "0.0.0.0:25571->25571/tcp"},
        ]
        status = self._status(js, containers, "25570", "RPG", 25571)
        assert 25571 not in status["free"]
        assert status["port"] != 25571
        assert "Assigned the next free port" in status["note"]

    def test_port_outside_the_pool_is_replaced_with_a_free_one(self, js):
        status = self._status(js, [], "", "RPG", 30000)
        assert status["port"] == 25565
        assert 30000 not in status["free"]
