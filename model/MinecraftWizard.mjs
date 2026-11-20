// Guided Minecraft server creation.
//
// Everything the wizard asks — client choice, option lists, and the commands
// for preflight/install — lives here so QML and tests share one source of
// truth. Pure helpers only: no QML objects, no side effects.

import { shell } from './Shell.mjs';
import { Gaming } from './Gaming.mjs';
import { publishedPorts } from './Docker.mjs';

export class MinecraftWizard {
  // Step 1: which client will the operator use to join the server?
  clientOptions() {
    return [
      { value: "prism", label: "Prism Launcher", detail: "Instances, modpacks and one-click join" },
      { value: "official", label: "Official Minecraft Launcher", detail: "Mojang's standard launcher" }
    ];
  }

  // Step 2: how should the server process be run?
  runModeOptions() {
    return [
      { value: "docker", label: "Docker", detail: "The hub pulls the image and creates the container" },
      { value: "manual", label: "Run it myself", detail: "Show me the command to run by hand" }
    ];
  }

  // Step 3: the server options. Labels explain the trade-off so a first-time
  // user can finish the wizard without reading the image documentation.
  serverTypeOptions() {
    return [
      { value: "PAPER", label: "Paper — fast, plugin-friendly" },
      { value: "VANILLA", label: "Vanilla — plain Mojang server" },
      { value: "FORGE", label: "Forge — modded server" },
      { value: "FABRIC", label: "Fabric — modded server" }
    ];
  }

  versionOptions() {
    return [
      { value: "LATEST", label: "Latest (recommended)" },
      { value: "26.3", label: "26.3" },
      { value: "1.21.1", label: "1.21.1" },
      { value: "1.20.1", label: "1.20.1" }
    ];
  }

  memoryOptions() {
    return [
      { value: "2G", label: "2 GB — small vanilla worlds" },
      { value: "4G", label: "4 GB — recommended" },
      { value: "6G", label: "6 GB — modded servers" },
      { value: "8G", label: "8 GB — large modpacks" }
    ];
  }

  difficultyOptions() {
    return [
      { value: "PEACEFUL", label: "Peaceful" },
      { value: "EASY", label: "Easy" },
      { value: "NORMAL", label: "Normal" },
      { value: "HARD", label: "Hard" }
    ];
  }

  // Detects both clients in one pass. Output is id<TAB>0|1 per line, matching
  // the shape the hub's other app scans already use.
  clientCheckCommand() {
    return ["sh", "-c", [
      "has_cmd(){ command -v \"$1\" >/dev/null 2>&1; }",
      "has_flatpak(){ command -v flatpak >/dev/null 2>&1 && flatpak info \"$1\" >/dev/null 2>&1; }",
      "if has_cmd prismlauncher || has_flatpak org.prismlauncher.PrismLauncher; then p=1; else p=0; fi",
      "if has_cmd minecraft-launcher || has_flatpak com.mojang.Minecraft; then o=1; else o=0; fi",
      "printf 'prism\\t%s\\nofficial\\t%s\\n' \"$p\" \"$o\""
    ].join("\n")];
  }

  parseClientScan(text) {
    var found = { prism: false, official: false };
    shell.nonEmptyLines(text).forEach(function (line) {
      var parts = line.split("\t");
      var key = shell.trim(parts[0] || "");
      if (key === "prism" || key === "official")
        found[key] = shell.trim(parts[1] || "") === "1";
    });
    return found;
  }

  // Install commands mirror the launcher catalog. Prism is reused from there;
  // the official launcher is retired from the catalog but still an explicit
  // choice in this wizard, so it gets its own shell chain here.
  clientInstallCommand(client) {
    if (client === "official") {
      return ["sh", "-c",
        "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm minecraft-launcher; " +
        "elif command -v paru >/dev/null 2>&1; then paru -S --needed --noconfirm minecraft-launcher; " +
        "elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.mojang.Minecraft; " +
        "else echo 'Install yay/paru or flatpak to install the official launcher.'; exit 1; fi"
      ];
    }
    var def = new Gaming().defById("prismlauncher");
    return ["sh", "-c", def && def.installCmd
      ? def.installCmd
      : "echo 'No supported installer found for Prism Launcher.'; exit 1"];
  }

  clientName(client) {
    return client === "official" ? "Official Minecraft Launcher" : "Prism Launcher";
  }

  // An installed Prism modpack is a complete server recipe: its loader/version,
  // mods, (when present) its save and the minecraft dir that holds kubejs and
  // config. Read both Prism layouts so a Flatpak install is offered alongside
  // a native one. Output is tab-separated rows:
  // id, name, loader, version, mods dir, world dir, minecraft dir.
  modpackScanCommand(homeDir) {
    var h = shell.trim(String(homeDir || ""));
    var roots = [
      h + "/.local/share/PrismLauncher/instances",
      h + "/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
    ];
    var py = [
      "import glob, json, os, sys",
      "for root in sys.argv[1:]:",
      "    for cfg in sorted(glob.glob(os.path.join(root, '*', 'instance.cfg'))):",
      "        d = os.path.dirname(cfg)",
      "        pack = os.path.join(d, 'mmc-pack.json')",
      "        if not os.path.isfile(pack):",
      "            continue",
      "        name = os.path.basename(d)",
      "        for line in open(cfg, errors='replace'):",
      "            if line.startswith('name='):",
      "                name = line[5:].strip()",
      "                break",
      "        try:",
      "            comps = {c.get('uid', ''): c.get('version', '') for c in json.load(open(pack)).get('components', [])}",
      "        except Exception:",
      "            continue",
      "        mc = comps.get('net.minecraft', '')",
      "        if comps.get('net.minecraftforge'):",
      "            loader, version = 'FORGE', mc + '-' + comps['net.minecraftforge']",
      "        elif comps.get('net.fabricmc.fabric-loader'):",
      "            loader, version = 'FABRIC', mc",
      "        else:",
      "            continue",
      "        mods = os.path.join(d, 'minecraft', 'mods')",
      "        if not os.path.isdir(mods):",
      "            continue",
      "        saves = sorted(glob.glob(os.path.join(d, 'minecraft', 'saves', '*', 'level.dat')))",
      "        world = os.path.dirname(saves[0]) if saves else ''",
      "        print('\\t'.join([os.path.basename(d), name, loader, version, mods, world, os.path.join(d, 'minecraft')]))"
    ].join("\n");
    return ["python3", "-c", py].concat(roots);
  }

  parseModpackScan(text) {
    return shell.nonEmptyLines(text).map(function (line) {
      var parts = line.split("\t");
      return {
        id: shell.trim(parts[0] || ""),
        name: shell.trim(parts[1] || ""),
        loader: shell.trim(parts[2] || ""),
        version: shell.trim(parts[3] || ""),
        modsDir: shell.trim(parts[4] || ""),
        worldDir: shell.trim(parts[5] || ""),
        supportDir: shell.trim(parts[6] || "")
      };
    }).filter(function (m) {
      // The hub's own join instance carries Fabric mods but is not a modpack.
      var managed = m.id === "vemberos-server" || m.id === "vemberos-vanilla";
      return !managed && m.id.length > 0 && m.modsDir.length > 0 &&
        (m.loader === "FORGE" || m.loader === "FABRIC");
    });
  }

  modpackOptions(modpacks) {
    var options = [{ value: "", label: "None — choose the options below",
      detail: "Start from a plain server" }];
    var list = Array.isArray(modpacks) ? modpacks : [];
    for (var i = 0; i < list.length; i++) {
      var m = list[i] || {};
      options.push({
        value: m.id || "",
        label: (m.name || m.id || "Modpack") + " · " + (m.loader || "") + " " + (m.version || ""),
        detail: "Use its installed mods" + (m.worldDir ? " and world save" : "")
      });
    }
    return options;
  }

  // --- Port pool -----------------------------------------------------------
  // 25565 is the Minecraft default and is taken by the first server. Give the
  // wizard a predictable run of slots so a second server gets a working
  // default instead of colliding with the one already running.
  portPool() {
    var out = [];
    for (var port = 25565; port <= 25584; port++) out.push(port);
    return out;
  }

  // Docker publishes host ports; read them from the same `docker ps -a` poll
  // that already feeds the Servers tab. Stopped containers still reserve their
  // published ports, so this covers servers that are not currently running.
  usedContainerPorts(containers) {
    var out = [];
    var list = Array.isArray(containers) ? containers : [];
    for (var i = 0; i < list.length; i++) {
      var ports = publishedPorts((list[i] || {}).ports);
      for (var j = 0; j < ports.length; j++)
        if (out.indexOf(ports[j]) === -1) out.push(ports[j]);
    }
    return out.sort(function (a, b) { return a - b; });
  }

  portOwner(containers, port) {
    var list = Array.isArray(containers) ? containers : [];
    var wanted = Number(port);
    for (var i = 0; i < list.length; i++) {
      var c = list[i] || {};
      if (publishedPorts(c.ports).indexOf(wanted) !== -1)
        return shell.trim(c.name || "") || "";
    }
    return "";
  }

  // Catch listeners that are not Docker containers (/proc/net/tcp and tcp6,
  // state 0A = LISTEN). The kernel's own view is authoritative: a port that is
  // bound cannot be published by Docker, whatever the container list says.
  listeningPortsCommand() {
    var py = [
      "import sys",
      "seen = set()",
      "for path in sys.argv[1:]:",
      "    try:",
      "        lines = open(path).read().splitlines()[1:]",
      "    except Exception:",
      "        continue",
      "    for line in lines:",
      "        f = line.split()",
      "        if len(f) < 4 or f[3] != '0A':",
      "            continue",
      "        try:",
      "            seen.add(int(f[1].rsplit(':', 1)[1], 16))",
      "        except Exception:",
      "            continue",
      "for p in sorted(seen):",
      "    print(p)"
    ].join("\n");
    return ["python3", "-c", py, "/proc/net/tcp", "/proc/net/tcp6"];
  }

  parseListeningPorts(text) {
    var out = [];
    shell.nonEmptyLines(text).forEach(function (line) {
      var port = parseInt(shell.trim(line), 10);
      if (isFinite(port) && port > 0 && port <= 65535 && out.indexOf(port) === -1)
        out.push(port);
    });
    return out.sort(function (a, b) { return a - b; });
  }

  chooseFreePort(free, currentPort) {
    var list = Array.isArray(free) ? free : [];
    var current = Number(currentPort);
    // Keep an operator's existing choice if it is still free; otherwise take
    // the first slot in the pool.
    if (isFinite(current) && list.indexOf(current) !== -1) return current;
    return list.length > 0 ? list[0] : null;
  }

  portStatus(containers, listeningText, currentPort) {
    var used = this.usedContainerPorts(containers);
    var listeners = this.parseListeningPorts(listeningText);
    for (var i = 0; i < listeners.length; i++)
      if (used.indexOf(listeners[i]) === -1) used.push(listeners[i]);
    used.sort(function (a, b) { return a - b; });

    var pool = this.portPool();
    var free = pool.filter(function (p) { return used.indexOf(p) === -1; });
    var chosen = this.chooseFreePort(free, currentPort);
    var options = free.map(function (p) {
      return { value: String(p), label: String(p) + (p === 25565 ? " — default" : " — free") };
    });

    var note = "";
    var changed = Number(currentPort) !== chosen;
    if (chosen === null) {
      note = "All ports " + pool[0] + "–" + pool[pool.length - 1] +
        " are in use. Free one before creating another server.";
    } else if (used.indexOf(25565) !== -1 && chosen !== 25565) {
      var owner = this.portOwner(containers, 25565);
      note = "25565 is in use" + (owner ? " by " + owner : "") +
        " — using " + chosen + ".";
    } else if (changed) {
      note = "Assigned the next free port " + chosen + ".";
    }
    return { used: used, free: free, options: options, port: chosen, note: note };
  }
}

export function clientOptions(...args) { return new MinecraftWizard().clientOptions(...args); }
export function runModeOptions(...args) { return new MinecraftWizard().runModeOptions(...args); }
export function serverTypeOptions(...args) { return new MinecraftWizard().serverTypeOptions(...args); }
export function versionOptions(...args) { return new MinecraftWizard().versionOptions(...args); }
export function memoryOptions(...args) { return new MinecraftWizard().memoryOptions(...args); }
export function difficultyOptions(...args) { return new MinecraftWizard().difficultyOptions(...args); }
export function clientCheckCommand(...args) { return new MinecraftWizard().clientCheckCommand(...args); }
export function parseClientScan(...args) { return new MinecraftWizard().parseClientScan(...args); }
export function clientInstallCommand(...args) { return new MinecraftWizard().clientInstallCommand(...args); }
export function clientName(...args) { return new MinecraftWizard().clientName(...args); }
export function modpackScanCommand(...args) { return new MinecraftWizard().modpackScanCommand(...args); }
export function parseModpackScan(...args) { return new MinecraftWizard().parseModpackScan(...args); }
export function modpackOptions(...args) { return new MinecraftWizard().modpackOptions(...args); }
export function portPool(...args) { return new MinecraftWizard().portPool(...args); }
export function usedContainerPorts(...args) { return new MinecraftWizard().usedContainerPorts(...args); }
export function portOwner(...args) { return new MinecraftWizard().portOwner(...args); }
export function listeningPortsCommand(...args) { return new MinecraftWizard().listeningPortsCommand(...args); }
export function parseListeningPorts(...args) { return new MinecraftWizard().parseListeningPorts(...args); }
export function chooseFreePort(...args) { return new MinecraftWizard().chooseFreePort(...args); }
export function portStatus(...args) { return new MinecraftWizard().portStatus(...args); }
