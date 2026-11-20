// Launcher/app catalog, Steam and Battle.net helpers.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Gaming.name(...)` while tests use `new Gaming()`.

import { shell } from './Shell.mjs';
import { publishedPorts } from './Docker.mjs';

export class Gaming {
  catalog() {
  return [
    {
      id: "heroic",
      name: "Heroic Games Launcher",
      description: "Play Epic Games, GOG, and Amazon titles on Linux.",
      category: "launchers",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/com.heroicgameslauncher.hgl.png",
      launchCmd: ["sh", "-c", "command -v heroic >/dev/null 2>&1 && exec heroic || command -v heroic-games-launcher >/dev/null 2>&1 && exec heroic-games-launcher || exec flatpak run com.heroicgameslauncher.hgl"],
      installCmd: "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm heroic-games-launcher-bin; elif command -v paru >/dev/null 2>&1; then paru -S --needed --noconfirm heroic-games-launcher-bin; elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.heroicgameslauncher.hgl; else echo 'Install yay/paru or flatpak to install Heroic.'; exit 1; fi"
    },
    {
      id: "lutris",
      name: "Lutris",
      description: "Game manager for Linux with runners and installers.",
      category: "launchers",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/lutris.png",
      launchCmd: ["sh", "-c", "command -v lutris >/dev/null 2>&1 && exec lutris || exec flatpak run net.lutris.Lutris"],
      installCmd: "if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm lutris; elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub net.lutris.Lutris; else echo 'No supported installer found for Lutris.'; exit 1; fi"
    },
    {
      id: "prismlauncher",
      name: "Prism Launcher",
      description: "Minecraft launcher with modpack and instance management.",
      category: "minecraft",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/org.prismlauncher.PrismLauncher.png",
      launchCmd: ["sh", "-c", "command -v prismlauncher >/dev/null 2>&1 && exec prismlauncher || exec flatpak run org.prismlauncher.PrismLauncher"],
      installCmd: "if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm prismlauncher; elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub org.prismlauncher.PrismLauncher; else echo 'No supported installer found for Prism Launcher.'; exit 1; fi"
    },
    {
      id: "curseforge",
      name: "CurseForge",
      description: "Mod manager for Minecraft and other supported games (best-effort detection).",
      category: "mods",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/curseforge.png",
      launchCmd: ["sh", "-c", "command -v curseforge >/dev/null 2>&1 && exec curseforge || (app=$(ls \"$HOME\"/Applications/CurseForge*.AppImage \"$HOME\"/Applications/curseforge*.AppImage 2>/dev/null | head -n1); if [ -n \"$app\" ]; then exec \"$app\"; fi) || exec flatpak run com.curseforge.curseforge"],
      installCmd: "if command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.curseforge.curseforge; else echo 'CurseForge on Linux is often installed via AppImage or Flatpak. Install Flatpak or download the AppImage to ~/Applications.'; exit 1; fi"
    },
    {
      id: "discord",
      name: "Discord / Vesktop",
      description: "Voice, video, and text chat — Discord or the Vesktop client.",
      category: "apps",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/discord.png",
      // Vesktop is a Discord client, so it satisfies this row. Try the native
      // Discord binaries first, then Vesktop, then the Flatpak builds.
      launchCmd: ["sh", "-c", "command -v discord >/dev/null 2>&1 && exec discord || command -v Discord >/dev/null 2>&1 && exec Discord || command -v vesktop >/dev/null 2>&1 && exec vesktop || command -v Vesktop >/dev/null 2>&1 && exec Vesktop || exec flatpak run com.discordapp.Discord || exec flatpak run dev.vencord.Vesktop"],
      installCmd: "if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm discord; elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.discordapp.Discord; else echo 'No supported installer found for Discord.'; exit 1; fi"
    }
  ];
  }

  scanCommand() {
  // Output: id\tinstalled(0/1)\trunning(0/1)\tnote
  var script = [
    "set -eu",
    "has_cmd(){ command -v \"$1\" >/dev/null 2>&1; }",
    "has_flatpak(){ command -v flatpak >/dev/null 2>&1 && flatpak info \"$1\" >/dev/null 2>&1; }",
    "running_any(){ for p in \"$@\"; do pgrep -x \"$p\" >/dev/null 2>&1 && return 0; done; return 1; }",
    "emit(){ printf '%s\\t%s\\t%s\\t%s\\n' \"$1\" \"$2\" \"$3\" \"$4\"; }",
    // heroic
    "if has_cmd heroic || has_cmd heroic-games-launcher || has_flatpak com.heroicgameslauncher.hgl; then ih=1; else ih=0; fi; if running_any heroic heroic-games-launcher; then rh=1; else rh=0; fi; emit heroic \"$ih\" \"$rh\" ''",
    // lutris
    "if has_cmd lutris || has_flatpak net.lutris.Lutris; then il=1; else il=0; fi; if running_any lutris; then rl=1; else rl=0; fi; emit lutris \"$il\" \"$rl\" ''",
    // prismlauncher
    "if has_cmd prismlauncher || has_flatpak org.prismlauncher.PrismLauncher; then ip=1; else ip=0; fi; if running_any prismlauncher; then rp=1; else rp=0; fi; emit prismlauncher \"$ip\" \"$rp\" ''",
    // curseforge
    "cf_app=$(ls \"$HOME\"/Applications/CurseForge*.AppImage \"$HOME\"/Applications/curseforge*.AppImage 2>/dev/null | head -n1 || true); if has_cmd curseforge || [ -n \"$cf_app\" ] || has_flatpak com.curseforge.curseforge; then ic=1; else ic=0; fi; if running_any curseforge CurseForge; then rc=1; else rc=0; fi; emit curseforge \"$ic\" \"$rc\" \"$cf_app\"",
    // discord
    // Vesktop counts as a Discord client, in native or Flatpak form.
    "if has_cmd discord || has_cmd Discord || has_cmd vesktop || has_cmd Vesktop || has_flatpak com.discordapp.Discord || has_flatpak dev.vencord.Vesktop; then idc=1; else idc=0; fi; if running_any discord Discord vesktop Vesktop; then rdc=1; else rdc=0; fi; emit discord \"$idc\" \"$rdc\" ''"
  ].join("\n");
  return ["sh", "-c", script];
  }

  parseScan(text, catalog) {
  var byId = {};
  var rows = shell.nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var parts = rows[i].split("\t");
    var id = shell.trim(parts[0] || "");
    if (!id) continue;
    byId[id] = {
      installed: shell.trim(parts[1] || "0") === "1",
      running: shell.trim(parts[2] || "0") === "1",
      note: shell.trim(parts.slice(3).join("\t") || "")
    };
  }
  var out = [];
  var cat = Array.isArray(catalog) ? catalog : [];
  for (var j = 0; j < cat.length; j++) {
    var def = cat[j] || {};
    var st = byId[def.id] || { installed: false, running: false, note: "" };
    out.push({
      id: def.id || "",
      name: def.name || def.id || "App",
      description: def.description || "",
      category: def.category || "apps",
      icon: def.icon || "",
      installed: !!st.installed,
      running: !!st.running,
      note: st.note || ""
    });
  }
  return out;
  }

  defById(id) {
  var cat = catalog();
  for (var i = 0; i < cat.length; i++) {
    if (cat[i] && cat[i].id === id) return cat[i];
  }
  return null;
  }

  steamInstallCommand() {
  return "if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm steam; " +
    "elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.valvesoftware.Steam; " +
    "else echo 'No supported installer found for Steam.'; exit 1; fi";
  }

  battlenetSetupUrl() {
  return "https://lutris.net/games/battlenet/";
  }

  battlenetGameCountCommand(homeDir) {
  var roots = [
    String(homeDir || "") + "/Games/battlenet",
    "/mnt/games/Battlenet",
    "/mnt/games/Battle.net",
    "/mnt/games/Blizzard"
  ];
  var cmd = ["find"];
  for (var i = 0; i < roots.length; i++) cmd.push(roots[i]);
  cmd.push("-maxdepth", "4", "(", "-name", ".build.info", "-o", "-name", ".product.db", ")");
  return cmd;
  }

  parseBattlenetGameCount(text) {
  var paths = shell.nonEmptyLines(text);
  var seen = {};
  var count = 0;
  for (var i = 0; i < paths.length; i++) {
    var p = shell.trim(paths[i]);
    if (!p) continue;
    // game directory is parent of marker file
    var dir = p.replace(/\/[^\/]+$/, "");
    if (!dir) dir = p;
    if (!seen[dir]) {
      seen[dir] = true;
      count += 1;
    }
  }
  return count;
  }

  steamLibraryVdfPath(homeDir) {
  return String(homeDir || "") + "/.local/share/Steam/steamapps/libraryfolders.vdf";
  }

  battlenetPrefixPath(homeDir) {
  return String(homeDir || "") + "/Games/battlenet";
  }

  steamRootPath(homeDir) {
  return String(homeDir || "") + "/.local/share/Steam";
  }

  parseLibraryPaths(text) {
  // Best-effort parse of Steam libraryfolders.vdf: capture "path" values.
  var out = [];
  var re = /"path"\s*"([^"]+)"/gi;
  var m;
  while ((m = re.exec(String(text || ""))) !== null) {
    if (m[1])
      out.push(String(m[1]).replace(/\\\\/g, "\\"));
  }
  return out;
  }

  parseSteamManifestScan(text) {
  var t = shell.trim(text);
  var out = { count: 0, servers: [] };
  if (t.length === 0)
    return out;
  try {
    var obj = JSON.parse(t);
    if (obj && typeof obj === "object") {
      var n = Number(obj.count);
      out.count = isNaN(n) ? 0 : n;
      if (Array.isArray(obj.servers)) {
        for (var i = 0; i < obj.servers.length; i++) {
          var srv = obj.servers[i] || {};
          out.servers.push({
            appid: shell.trim(srv.appid || ""),
            name: shell.trim(srv.name || ""),
            installdir: shell.trim(srv.installdir || "")
          });
        }
      }
      return out;
    }
  } catch (e) {}
  // fallback: plain number or line count
  if (/^\d+$/.test(t)) {
    out.count = Number(t);
    return out;
  }
  var rows = shell.nonEmptyLines(t);
  if (rows.length === 1 && /^\d+$/.test(shell.trim(rows[0]))) {
    out.count = Number(shell.trim(rows[0]));
    return out;
  }
  out.count = rows.length;
  return out;
  }

  steamManifestCountCommandForDirs(steamappsDirs) {
  var dirs = Array.isArray(steamappsDirs) ? steamappsDirs : [];
  var filtered = [];
  for (var i = 0; i < dirs.length; i++) {
    if (shell.trim(dirs[i]).length > 0)
      filtered.push(String(dirs[i]));
  }
  if (filtered.length === 0)
    return ["python3", "-c", "import json; print(json.dumps({'count': 0, 'servers': []}))"];
  var script = "import sys,glob,os,re,json\n" +
    "keep=0\n" +
    "servers=[]\n" +
    "seen=set()\n" +
    "for d in sys.argv[1:]:\n" +
    "  for m in glob.glob(os.path.join(d,'appmanifest_*.acf')):\n" +
    "    if m in seen:\n" +
    "      continue\n" +
    "    seen.add(m)\n" +
    "    try:\n" +
    "      t=open(m,'r',errors='ignore').read()\n" +
    "    except Exception:\n" +
    "      continue\n" +
    "    name_m=re.search(r'\\\"name\\\"\\s+\\\"([^\\\"]*)\\\"', t, re.I)\n" +
    "    name=(name_m.group(1) if name_m else '')\n" +
    "    n=name.lower()\n" +
    "    if ('proton' in n or 'steam linux runtime' in n or 'steamworks common redistributables' in n):\n" +
    "      continue\n" +
    "    appid_m=re.search(r'\\\"appid\\\"\\s+\\\"([^\\\"]*)\\\"', t, re.I)\n" +
    "    inst_m=re.search(r'\\\"installdir\\\"\\s+\\\"([^\\\"]*)\\\"', t, re.I)\n" +
    "    appid=(appid_m.group(1) if appid_m else '')\n" +
    "    installdir=(inst_m.group(1) if inst_m else '')\n" +
    "    if ('dedicated server' in n):\n" +
    "      servers.append({'appid': appid, 'name': name, 'installdir': installdir})\n" +
    "      continue\n" +
    "    keep+=1\n" +
    "print(json.dumps({'count': keep, 'servers': servers}))\n";
  var cmd = ["python3", "-c", script];
  for (var j = 0; j < filtered.length; j++) cmd.push(filtered[j]);
  return cmd;
  }

  // Prism stores each modpack as a directory containing instance.cfg. Instance
  // names can contain spaces ("Create- Astral"), so count with find over quoted
  // roots rather than interpolating a glob into a shell string. Both the native
  // and Flatpak data roots are checked; a missing root simply contributes none.
  prismInstanceCountCommand(homeDir) {
  var h = String(homeDir || "");
  var roots = [
    h + "/.local/share/PrismLauncher/instances",
    h + "/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
  ];
  var cmd = ["sh", "-c",
    "for d in \"$@\"; do [ -d \"$d\" ] || continue; " +
    "find \"$d\" -mindepth 2 -maxdepth 2 -type f -name instance.cfg -print; done",
    "sh"];
  for (var i = 0; i < roots.length; i++) cmd.push(roots[i]);
  return cmd;
  }

  parsePrismInstanceCount(text) {
  return shell.nonEmptyLines(text).length;
  }

  // The vanilla launcher stores each installed version as
  // <versions>/<name>/<name>.json. The two manifests at the top level are not
  // versions, so only depth-2 files count. Flatpak keeps its data elsewhere.
  minecraftVersionCountCommand(homeDir) {
  var h = String(homeDir || "");
  var roots = [
    h + "/.minecraft/versions",
    h + "/.var/app/com.mojang.Minecraft/.minecraft/versions"
  ];
  var cmd = ["sh", "-c",
    "for d in \"$@\"; do [ -d \"$d\" ] || continue; " +
    "find \"$d\" -mindepth 2 -maxdepth 2 -type f -name '*.json' -print; done",
    "sh"];
  for (var i = 0; i < roots.length; i++) cmd.push(roots[i]);
  return cmd;
  }

  parseMinecraftVersionCount(text) {
  var paths = shell.nonEmptyLines(text);
  var dirs = {};
  for (var i = 0; i < paths.length; i++) {
    var p = shell.trim(paths[i]);
    if (!p) continue;
    // Count version folders, not json files: a version may ship more than one.
    var dir = p.replace(/\/[^\/]+$/, "");
    if (dir) dirs[dir] = true;
  }
  return Object.keys(dirs).length;
  }

  // Heroic keeps one install-info file per store. Each installed game is a key
  // in that JSON; "__timestamp" is bookkeeping, not a game. A game still being
  // installed is already listed (its installPath fills in when it finishes),
  // so counting keys reflects what Heroic considers installed. Native config is
  // ~/.config/heroic; Flatpak keeps it under ~/.var/app/<id>/config/heroic.
  heroicGameCountCommand(homeDir) {
  var h = String(homeDir || "");
  var script = "import sys,os,json\n" +
    "seen=set()\n" +
    "for base in sys.argv[1:]:\n" +
    "  for store in ('legendary','gog','nile'):\n" +
    "    p=os.path.join(base,'store_cache',store+'_install_info.json')\n" +
    "    try:\n" +
    "      d=json.load(open(p,errors='ignore'))\n" +
    "    except Exception:\n" +
    "      continue\n" +
    "    if not isinstance(d,dict):\n" +
    "      continue\n" +
    "    for k in d:\n" +
    "      if k!='__timestamp':\n" +
    "        seen.add(k)\n" +
    "print(len(seen))\n";
  var cmd = ["python3", "-c", script];
  cmd.push(h + "/.config/heroic");
  cmd.push(h + "/.var/app/com.heroicgameslauncher.hgl/config/heroic");
  return cmd;
  }

  parseHeroicGameCount(text) {
  var t = shell.trim(text);
  return /^\d+$/.test(t) ? Number(t) : 0;
  }

  // One keyword list for both the Servers list and the Storage size card. It
  // used to live inline in GamesTab.qml; a second consumer made a shared,
  // testable definition necessary. Container names come from Docker, not from
  // the form, so a strict allowlist here still cannot reject a legitimate
  // server the operator created outside the hub.
  gameServerKeywords() {
  return ["minecraft", "valheim", "factorio", "palworld", "terraria", "ark",
    "cs2", "csgo", "rust", "satisfactory", "7dtd", "zomboid", "projectzomboid",
    "enshrouded", "foundry", "vintage", "vrising", "conan", "dayz", "game",
    "gameserver", "pterodactyl", "crafty", "steamcmd"];
  }

  gameServerContainers(list, steamServers) {
  var out = [];
  var containers = Array.isArray(list) ? list : [];
  var keys = this.gameServerKeywords();
  for (var i = 0; i < containers.length; i++) {
    var c = containers[i] || {};
    var hay = ((c.name || "") + " " + (c.image || "")).toLowerCase();
    var match = false;
    for (var k = 0; k < keys.length; k++) {
      if (hay.indexOf(keys[k]) !== -1) { match = true; break; }
    }
    if (match) out.push({
      serverType: "container", name: c.name || "unknown",
      image: c.image || "", state: c.state || "", status: c.status || "",
      ports: c.ports || ""
    });
  }
  var steam = Array.isArray(steamServers) ? steamServers : [];
  for (var s = 0; s < steam.length; s++) {
    var ss = steam[s] || {};
    out.push({
      serverType: "steam", name: ss.name || "Steam Dedicated Server",
      image: ss.appid ? ("AppID " + ss.appid) : "Steam dedicated server",
      state: "installed",
      status: ss.installdir ? ("Install dir: " + ss.installdir) : "Host install (Steam)",
      installdir: ss.installdir || "", appid: ss.appid || ""
    });
  }
  return out;
  }

  // Shared predicate for "is this a hub-managed Minecraft container?". Both
  // the client bar and the per-row Edit button use it, so neither carries a
  // separate copy of the image/name matching rule.
  isMinecraftContainer(c) {
    var obj = c || {};
    var hay = (((obj.name || "") + " " + (obj.image || ""))).toLowerCase();
    return hay.indexOf("minecraft") !== -1 || hay.indexOf("itzg") !== -1;
  }

  // The client bar is driven by the detected server list, not by a hardcoded
  // "Vember server" label. Only Minecraft containers become join targets.
  minecraftServers(containers) {
    var list = Array.isArray(containers) ? containers : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
      var c = list[i] || {};
      if (!this.isMinecraftContainer(c))
        continue;
      var ports = publishedPorts(c.ports || "");
      out.push({
        name: c.name || "Minecraft server",
        image: c.image || "",
        port: ports.length > 0 ? ports[0] : 0
      });
    }
    return out;
  }

  // Both size figures in one process: `du -sh` on the host path mounted at
  // /data (the space worlds actually use) and `docker ps -s` (writable layer
  // plus image). Names and paths are positional args to `sh -c`, never spliced
  // into the script text. A missing mount or a stopped container shows "-".
  gameServerSizeCommand(servers) {
  var list = Array.isArray(servers) ? servers : [];
  // One process returns both human figures plus raw bytes. `du -sh` is what
  // the Storage card prints; `du -sb` feeds the proportional blue slice. The
  // byte count is apparent size, so it can differ a little from the allocated
  // `-sh` value — the bar and the label are allowed that small disagreement.
  var script = "while [ $# -ge 3 ]; do\n" +
    "  name=$1; kind=$2; path=$3; shift 3\n" +
    "  csize='-'\n" +
    "  if [ \"$kind\" != 'steam' ]; then\n" +
    "    path=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/data\"}}{{.Source}}{{end}}{{end}}' \"$name\" 2>/dev/null)\n" +
    "    csize=$(docker ps -a -s --no-trunc --filter \"name=^/${name}$\" --format '{{.Size}}' 2>/dev/null)\n" +
    "    [ -n \"$csize\" ] || csize='-'\n" +
    "  fi\n" +
    "  dsize='-'; dbytes=0\n" +
    "  if [ -n \"$path\" ] && [ -d \"$path\" ]; then\n" +
    "    dsize=$(du -sh \"$path\" 2>/dev/null | cut -f1)\n" +
    "    [ -n \"$dsize\" ] || dsize='-'\n" +
    "    dbytes=$(du -sb \"$path\" 2>/dev/null | cut -f1)\n" +
    "    case \"$dbytes\" in ''|*[!0-9]*) dbytes=0 ;; esac\n" +
    "  fi\n" +
    "  printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$path\" \"$dsize\" \"$csize\" \"$dbytes\"\n" +
    "done\n";
  var cmd = ["sh", "-c", script, "sh"];
  for (var i = 0; i < list.length; i++) {
    var s = list[i] || {};
    var name = shell.trim(String(s.name || ""));
    if (name.length === 0) continue;
    cmd.push(name);
    cmd.push(s.serverType === "steam" ? "steam" : "container");
    cmd.push(s.serverType === "steam" ? shell.trim(String(s.installdir || "")) : "");
  }
  return cmd;
  }

  parseGameServerSizes(text) {
  var out = [];
  var lines = String(text || "").split(/\r?\n/);
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t");
    if (parts.length < 4) continue;
    var name = shell.trim(parts[0]);
    if (name.length === 0) continue;
    // The byte field is optional so an older four-column response still parses;
    // it simply contributes zero to the bar.
    var bytes = parts.length > 4 ? parseInt(parts[4], 10) : 0;
    if (!isFinite(bytes) || bytes < 0) bytes = 0;
    out.push({
      name: name,
      path: shell.trim(parts[1]),
      dataSize: shell.trim(parts[2]) || "-",
      containerSize: shell.trim(parts[3]) || "-",
      dataBytes: bytes
    });
  }
  return out;
  }

  // Bytes across every detected server, for the blue slice of the partition
  // bar. This lives in the model so the arithmetic is tested alongside the
  // parser that produced the numbers.
  // Minecraft's multiplayer list is a small uncompressed NBT file. Prism's
  // JoinServerOnLaunch writes its own entry with hidden=1, which keeps the
  // server out of the Multiplayer screen after a disconnect. Emitting the file
  // here lets the hub keep one visible entry without an NBT parser in QML.
  utf8Bytes(text) {
    var s = String(text || "");
    var out = [];
    for (var i = 0; i < s.length; i++) {
      var c = s.charCodeAt(i);
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
      else out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    }
    return out;
  }

  minecraftServerListBytes(address, name) {
    var self = this;
    var addr = shell.trim(String(address || "")) || "localhost:25565";
    var label = shell.trim(String(name || "")) || "Vember OS";
    var out = [];
    function put() { for (var i = 0; i < arguments.length; i++) out.push(arguments[i]); }
    function text(value) {
      var bytes = self.utf8Bytes(value);
      put((bytes.length >> 8) & 255, bytes.length & 255);
      for (var i = 0; i < bytes.length; i++) put(bytes[i]);
    }
    put(0x0a); text("");                    // root TAG_Compound
    put(0x09); text("servers");             // TAG_List of compounds
    put(0x0a, 0x00, 0x00, 0x00, 0x01);      // element type + one entry
    // List elements carry no tag/name header — their children start here.
    put(0x01); text("hidden"); put(0x00);   // visible in the multiplayer list
    put(0x08); text("ip"); text(addr);
    put(0x08); text("name"); text(label);
    put(0x00);                              // end entry
    put(0x00);                              // end root
    return out;
  }

  // POSIX printf writes the exact bytes, including NULs, straight to the file.
  minecraftServerListCommand(gameDir, address, name) {
    var dir = shell.trim(String(gameDir || ""));
    if (dir.charAt(0) !== "/" || dir.indexOf("\n") !== -1)
      return ["sh", "-c", "exit 1"];
    var bytes = this.minecraftServerListBytes(address, name);
    var esc = "";
    for (var i = 0; i < bytes.length; i++) {
      var oct = bytes[i].toString(8);
      while (oct.length < 3) oct = "0" + oct;
      esc += "\\" + oct;
    }
    // Skip layouts that are not installed instead of creating empty instances.
    return ["sh", "-c", "[ -d " + shell.quote(dir) + " ] || exit 0; printf '" +
      esc + "' > " + shell.quote(dir + "/servers.dat")];
  }

  // Both the native and Flatpak Prism layouts, for the two instances the hub
  // launches. Other modpack instances keep their own server lists untouched.
  minecraftJoinGameDirs(homeDir) {
    var h = shell.trim(String(homeDir || ""));
    if (!h) return [];
    var roots = [
      h + "/.local/share/PrismLauncher/instances",
      h + "/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
    ];
    var out = [];
    for (var i = 0; i < roots.length; i++) {
      out.push(roots[i] + "/minecraft-join/minecraft");
      out.push(roots[i] + "/minecraft-vanilla/minecraft");
    }
    return out;
  }

  // Two clean Prism instances cloned from the hub template: one joins the
  // local server, the other opens to the main menu. Prism's --server CLI flag
  // does not pass the address to modern (26.3) game arguments, so the address
  // lives in the join instance instead. Instance ids are local facts, like the
  // server paths.
  minecraftClientLaunchCommand(mode, instanceId) {
  var id = shell.trim(String(instanceId || ""));
  if (!id)
    id = String(mode || "") === "server" ? "minecraft-join" : "minecraft-vanilla";
  return ["prismlauncher", "--launch", id];
  }

  // A stable Prism instance id per server, so a later Launch from the Servers
  // list reuses the same instance without a registry. The template and the two
  // keybinding instances are reserved and never overwritten by a server.
  minecraftInstanceId(name) {
    var id = shell.trim(String(name || "")).toLowerCase()
      .replace(/[^a-z0-9._-]+/g, "-")
      .replace(/^-+|-+$/g, "").slice(0, 60);
    if (!id) id = "vember-server";
    if (["minecraft-server", "minecraft-join", "minecraft-vanilla",
         "vemberos-server", "vemberos-vanilla"].indexOf(id) !== -1)
      id = "server-" + id;
    return id;
  }

  // Create or refresh a Prism instance that auto-joins one hub-created server.
  // The template is a hub-owned vanilla 26.3 + Fabric + Controlify instance,
  // never one of the user-facing keybinding instances. An installed modpack can
  // still be chosen when the server is created from one. The sidecar remembers
  // the source and the chosen client so a later Launch uses the same recipe.
  // Idempotent: rerunning updates the address without losing mods.
  minecraftServerInstanceCommand(options) {
    var o = options || {};
    var home = shell.trim(String(o.homeDir || ""));
    var id = shell.trim(String(o.id || ""));
    var rawName = String(o.name || "");
    var rawAddress = String(o.address || "");
    var rawSource = String(o.sourceId || "");
    var rawClient = String(o.client || "");
    if (/[\r\n]/.test(rawName) || /[\r\n]/.test(rawAddress) ||
        /[\r\n]/.test(rawSource) || /[\r\n]/.test(rawClient))
      return ["sh", "-c", "exit 1"];
    var name = shell.trim(rawName).slice(0, 120);
    var address = shell.trim(rawAddress).slice(0, 200);
    var source = shell.trim(rawSource).replace(/[^A-Za-z0-9._-]/g, "");
    var client = shell.trim(rawClient) === "official" ? "official" : "prism";
    if (home.charAt(0) !== "/" || home.indexOf("\n") !== -1 ||
        !/^[A-Za-z0-9._-]+$/.test(id) || id.indexOf("..") !== -1 ||
        source.indexOf("..") !== -1 || !name || !address)
      return ["sh", "-c", "exit 1"];

    var meta = {
      homeDir: home, id: id, name: name, address: address, client: client,
      sourceId: source, listBytes: this.minecraftServerListBytes(address, name)
    };
    var py = [
      "import json, os, shutil, sys",
      "m = json.loads(sys.argv[1])",
      "home, sid = m['homeDir'], m['id']",
      "roots = [home + '/.local/share/PrismLauncher/instances',",
      "         home + '/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances']",
      "root = roots[0]",
      "for r in roots:",
      "    if os.path.isdir(r):",
      "        root = r",
      "        break",
      "dst = os.path.join(root, sid)",
      "sidecar = os.path.join(dst, 'vember-hub.json')",
      "prior = {}",
      "if os.path.isfile(sidecar):",
      "    try:",
      "        prior = json.load(open(sidecar))",
      "    except Exception:",
      "        prior = {}",
      "client = m.get('client') or prior.get('client') or 'prism'",
      "source = m.get('sourceId') or prior.get('sourceId') or 'minecraft-server'",
      "src = os.path.join(root, source)",
      "if not os.path.isfile(os.path.join(src, 'instance.cfg')):",
      "    src = os.path.join(root, 'minecraft-server')",
      "if not os.path.isfile(os.path.join(src, 'instance.cfg')):",
      "    sys.stderr.write('No Prism template instance found. Run Prism setup first.\\n')",
      "    sys.exit(2)",
      "os.makedirs(os.path.join(dst, 'minecraft'), exist_ok=True)",
      "lines = open(os.path.join(src, 'instance.cfg'), errors='replace').read().splitlines()",
      "out, seen = [], set()",
      "skip = ('lastLaunchTime=', 'lastTimePlayed=', 'totalTimePlayed=', 'uuid=')",
      "for line in lines:",
      "    key = line.split('=', 1)[0] if '=' in line else ''",
      "    if any(line.startswith(s) for s in skip):",
      "        continue",
      "    if key in ('name', 'JoinServerOnLaunch', 'JoinServerOnLaunchAddress'):",
      "        seen.add(key)",
      "        if key == 'name':",
      "            line = 'name=' + m['name']",
      "        elif key == 'JoinServerOnLaunch':",
      "            line = 'JoinServerOnLaunch=true'",
      "        else:",
      "            line = 'JoinServerOnLaunchAddress=' + m['address']",
      "    out.append(line)",
      "if len(seen) < 3:",
      "    extra = []",
      "    if 'name' not in seen: extra.append('name=' + m['name'])",
      "    if 'JoinServerOnLaunch' not in seen: extra.append('JoinServerOnLaunch=true')",
      "    if 'JoinServerOnLaunchAddress' not in seen: extra.append('JoinServerOnLaunchAddress=' + m['address'])",
      "    if '[General]' in out:",
      "        i = out.index('[General]') + 1",
      "        out[i:i] = extra",
      "    else:",
      "        out = ['[General]'] + extra + out",
      "open(os.path.join(dst, 'instance.cfg'), 'w').write('\\n'.join(out) + '\\n')",
      "pack = os.path.join(src, 'mmc-pack.json')",
      "if os.path.isfile(pack):",
      "    shutil.copyfile(pack, os.path.join(dst, 'mmc-pack.json'))",
      "src_mods = os.path.join(src, 'minecraft', 'mods')",
      "dst_mods = os.path.join(dst, 'minecraft', 'mods')",
      "if os.path.isdir(src_mods) and not os.path.exists(dst_mods):",
      "    if source == 'minecraft-server':",
      "        shutil.copytree(src_mods, dst_mods)",
      "    else:",
      "        os.symlink(src_mods, dst_mods)",
      "open(os.path.join(dst, 'minecraft', 'servers.dat'), 'wb').write(bytes(m['listBytes']))",
      "json.dump({'container': m['name'], 'sourceId': source, 'address': m['address'],",
      "           'client': client}, open(sidecar, 'w'))",
      "print(dst)"
    ].join("\n");
    return ["python3", "-c", py, JSON.stringify(meta)];
  }

  // Prism setup is infrastructure, never a user-facing instance. It creates one
  // template and the two keybinding clones once. A valid seed keeps Controlify;
  // without one the template is generated from scratch, so an emptied Trash can
  // never block a launch.
  minecraftPrismSetupCommand(homeDir, seedDir) {
    var home = shell.trim(String(homeDir || ""));
    var seed = shell.trim(String(seedDir || ""));
    if (home.charAt(0) !== "/" || home.indexOf("\n") !== -1 ||
        (seed && (seed.charAt(0) !== "/" || seed.indexOf("\n") !== -1)))
      return ["sh", "-c", "exit 1"];
    var py = [
      "import json, os, shutil, sys",
      "m = json.loads(sys.argv[1])",
      "home, seed = m['homeDir'], m.get('seedDir', '')",
      "if not home.startswith('/') or chr(10) in home: sys.exit(2)",
      "roots = [home + '/.local/share/PrismLauncher/instances',",
      "         home + '/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances']",
      "root = roots[0]",
      "for r in roots:",
      "    if os.path.isdir(r):",
      "        root = r",
      "        break",
      "os.makedirs(root, exist_ok=True)",
      "",
      "def rewrite(src, dst, label, join):",
      "    lines = open(src, errors='replace').read().splitlines()",
      "    out, seen = [], set()",
      "    drop = ('lastLaunchTime=', 'lastTimePlayed=', 'totalTimePlayed=', 'uuid=',",
      "           'JoinServerOnLaunch=', 'JoinServerOnLaunchAddress=')",
      "    for line in lines:",
      "        key = line.split('=', 1)[0] if '=' in line else ''",
      "        if any(line.startswith(s) for s in drop):",
      "            continue",
      "        if key == 'name':",
      "            seen.add('name')",
      "            line = 'name=' + label",
      "        out.append(line)",
      "    if '[General]' in out:",
      "        head = out.index('[General]') + 1",
      "    else:",
      "        out = ['[General]'] + out",
      "        head = 1",
      "    if 'name' not in seen:",
      "        out.insert(head, 'name=' + label)",
      "        head += 1",
      "    if join:",
      "        out[head:head] = ['JoinServerOnLaunch=true', 'JoinServerOnLaunchAddress=' + join]",
      "    open(dst, 'w').write(chr(10).join(out) + chr(10))",
      "",
      "template = os.path.join(root, 'minecraft-server')",
      "created = []",
      "if not os.path.isfile(os.path.join(template, 'instance.cfg')):",
      "    if os.path.isdir(template):",
      "        shutil.rmtree(template)",
      "    os.makedirs(os.path.join(template, 'minecraft'), exist_ok=True)",
      "    if seed and os.path.isfile(os.path.join(seed, 'instance.cfg')):",
      "        shutil.copytree(seed, template, dirs_exist_ok=True)",
      "        rewrite(os.path.join(template, 'instance.cfg'), os.path.join(template, 'instance.cfg'),",
      "                'Vember Minecraft Template', '')",
      "    else:",
      "        cfg = ['[General]', 'ConfigVersion=1.3', 'InstanceType=OneSix',",
      "               'name=Vember Minecraft Template',",
      "               'notes=Hub-owned template. Do not launch directly.']",
      "        open(os.path.join(template, 'instance.cfg'), 'w').write(chr(10).join(cfg) + chr(10))",
      "        pack = {'formatVersion': 1, 'components': [",
      "            {'uid': 'org.lwjgl3', 'version': '3.4.3', 'dependencyOnly': True},",
      "            {'uid': 'net.minecraft', 'version': '26.3', 'important': True},",
      "            {'uid': 'net.fabricmc.intermediary', 'version': '26.3', 'dependencyOnly': True},",
      "            {'uid': 'net.fabricmc.fabric-loader', 'version': '0.20.1'}]}",
      "        json.dump(pack, open(os.path.join(template, 'mmc-pack.json'), 'w'), indent=4)",
      "    created.append('minecraft-server')",
      "",
      "for iid, label, join in (('minecraft-join', 'VemberOS Server', 'vemberos:25565'),",
      "                         ('minecraft-vanilla', 'Plain Vanilla', '')):",
      "    dst = os.path.join(root, iid)",
      "    if os.path.isfile(os.path.join(dst, 'instance.cfg')):",
      "        continue",
      "    if os.path.exists(dst):",
      "        shutil.rmtree(dst)",
      "    os.makedirs(os.path.join(dst, 'minecraft'), exist_ok=True)",
      "    rewrite(os.path.join(template, 'instance.cfg'), os.path.join(dst, 'instance.cfg'), label, join)",
      "    pack = os.path.join(template, 'mmc-pack.json')",
      "    if os.path.isfile(pack):",
      "        shutil.copyfile(pack, os.path.join(dst, 'mmc-pack.json'))",
      "    src_mods = os.path.join(template, 'minecraft', 'mods')",
      "    if os.path.isdir(src_mods):",
      "        shutil.copytree(src_mods, os.path.join(dst, 'minecraft', 'mods'))",
      "    created.append(iid)",
      "print(','.join(created) if created else 'ready')"
    ].join("\n");
    return ["python3", "-c", py, JSON.stringify({ homeDir: home, seedDir: seed })];
  }

  // Per-server client defaults live in the instance sidecars. One scan lets the
  // join bar show each server's saved choice after a hub restart.
  minecraftClientDefaultsCommand(homeDir) {
    var home = shell.trim(String(homeDir || ""));
    if (home.charAt(0) !== "/" || home.indexOf("\n") !== -1)
      return ["sh", "-c", "exit 1"];
    var py = [
      "import glob, json, os, sys",
      "home = sys.argv[1]",
      "if not home.startswith('/') or chr(10) in home: sys.exit(2)",
      "roots = [home + '/.local/share/PrismLauncher/instances',",
      "         home + '/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances']",
      "for root in roots:",
      "    for path in sorted(glob.glob(os.path.join(root, '*', 'vember-hub.json'))):",
      "        try:",
      "            m = json.load(open(path))",
      "            name = str(m.get('container', ''))",
      "            client = str(m.get('client', 'prism'))",
      "            if name and chr(9) not in name and chr(10) not in name:",
      "                print(name + chr(9) + ('official' if client == 'official' else 'prism'))",
      "        except Exception:",
      "            pass"
    ].join("\n");
    return ["python3", "-c", py, home];
  }

  parseMinecraftClientDefaults(text) {
    var out = {};
    shell.nonEmptyLines(text).forEach(function (line) {
      var parts = line.split("\t");
      var name = shell.trim(parts[0] || "");
      if (name) out[name] = shell.trim(parts[1] || "") === "official" ? "official" : "prism";
    });
    return out;
  }

  // The official launcher keeps its multiplayer list in an NBT servers.dat.
  // Insert one entry into the existing list instead of rewriting the file, so
  // entries Elena added by hand survive. Re-launching the same address is a
  // no-op rather than a duplicate.
  minecraftOfficialServerListCommand(homeDir, address, name) {
    var home = shell.trim(String(homeDir || ""));
    var addr = shell.trim(String(address || ""));
    var label = shell.trim(String(name || ""));
    if (home.charAt(0) !== "/" || home.indexOf("\n") !== -1 ||
        !addr || !label || /[\r\n]/.test(addr) || /[\r\n]/.test(label))
      return ["sh", "-c", "exit 1"];
    var py = [
      "import json, os, struct, sys",
      "m = json.loads(sys.argv[1])",
      "home, addr, label = m['homeDir'], m['address'], m['name']",
      "if not home.startswith('/') or chr(10) in home: sys.exit(2)",
      "",
      "def txt(v):",
      "    raw = v.encode('utf-8')",
      "    return struct.pack('>H', len(raw)) + raw",
      "def u1(b, i): return b[i], i + 1",
      "def u2(b, i): return struct.unpack_from('>H', b, i)[0], i + 2",
      "def i4(b, i): return struct.unpack_from('>i', b, i)[0], i + 4",
      "def text(b, i):",
      "    n, i = u2(b, i)",
      "    return b[i:i + n].decode('utf-8', 'replace'), i + n",
      "",
      "def skip(b, tag, i):",
      "    if tag == 1: return i + 1",
      "    if tag == 2: return i + 2",
      "    if tag in (3, 4): return i + 4",
      "    if tag in (5, 6): return i + 8",
      "    if tag == 7:",
      "        n, i = i4(b, i)",
      "        return i + n",
      "    if tag == 8:",
      "        _, i = text(b, i)",
      "        return i",
      "    if tag == 9:",
      "        et, i = u1(b, i)",
      "        n, i = i4(b, i)",
      "        for j in range(n):",
      "            i = skip(b, et, i)",
      "        return i",
      "    if tag == 10:",
      "        while i < len(b):",
      "            t, i = u1(b, i)",
      "            if t == 0: return i",
      "            _, i = text(b, i)",
      "            i = skip(b, t, i)",
      "        return i",
      "    if tag == 11:",
      "        n, i = i4(b, i)",
      "        return i + 4 * n",
      "    if tag == 12:",
      "        n, i = i4(b, i)",
      "        return i + 8 * n",
      "    return None",
      "",
      "def list_pos(b):",
      "    if not b or b[0] != 10: return None",
      "    _, i = text(b, 1)",
      "    t, i = u1(b, i)",
      "    if t != 9: return None",
      "    _, i = text(b, i)",
      "    et, i = u1(b, i)",
      "    if et != 10: return None",
      "    count_at = i",
      "    n, i = i4(b, i)",
      "    ips = []",
      "    # A TAG_List of compounds stores bare payloads: no per-entry tag or",
      "    # name, just fields followed by TAG_End. The list header already gave",
      "    # us the element type (10).",
      "    for j in range(n):",
      "        while i < len(b):",
      "            ft, i = u1(b, i)",
      "            if ft == 0: break",
      "            key, i = text(b, i)",
      "            if ft == 8:",
      "                val, i = text(b, i)",
      "                if key == 'ip': ips.append(val)",
      "            else:",
      "                i = skip(b, ft, i)",
      "    return count_at, n, i, ips",
      "",
      "def entry(ip, label):",
      "    out = bytearray()",
      "    out += bytes([1]) + txt('hidden') + bytes([0])",
      "    out += bytes([8]) + txt('ip') + txt(ip)",
      "    out += bytes([8]) + txt('name') + txt(label)",
      "    out += bytes([0])",
      "    return bytes(out)",
      "",
      "folder = os.path.join(home, '.minecraft')",
      "path = os.path.join(folder, 'servers.dat')",
      "raw = open(path, 'rb').read() if os.path.isfile(path) else b''",
      "pos = list_pos(raw)",
      "if pos is None:",
      "    raw = (bytes([10]) + txt('') + bytes([9]) + txt('servers') + bytes([10]) +",
      "           struct.pack('>i', 0) + bytes([0]))",
      "    pos = list_pos(raw)",
      "count_at, n, end, ips = pos",
      "if addr not in ips:",
      "    raw = (raw[:count_at] + struct.pack('>i', n + 1) +",
      "           raw[count_at + 4:end] + entry(addr, label) + raw[end:])",
      "os.makedirs(folder, exist_ok=True)",
      "open(path, 'wb').write(raw)",
      "print(str(len(ips) + (0 if addr in ips else 1)))"
    ].join("\n");
    return ["python3", "-c", py, JSON.stringify({ homeDir: home, address: addr, name: label })];
  }

  minecraftOfficialLaunchCommand() {
    return ["sh", "-c", [
      "if command -v minecraft-launcher >/dev/null 2>&1; then exec minecraft-launcher; fi",
      "if command -v flatpak >/dev/null 2>&1 && flatpak info com.mojang.Minecraft >/dev/null 2>&1; then exec flatpak run com.mojang.Minecraft; fi",
      "echo 'Official Minecraft Launcher not found.' >&2; exit 1"
    ].join("\n")];
  }

  // Bounded TCP readiness check on the loopback side of a published port.
  // Always exits 0: a slow first boot is a UI status, not a failed launch.
  minecraftPortWaitCommand(port, seconds) {
    var p = parseInt(port, 10);
    if (!isFinite(p) || p < 1 || p > 65535) return ["sh", "-c", "exit 1"];
    var n = parseInt(seconds, 10);
    if (!isFinite(n) || n < 1 || n > 300) n = 90;
    // A TCP connect is not enough: Docker's published-port proxy accepts the
    // socket even when the Java process inside is dead (e.g. a locked world).
    // Do the Minecraft status handshake and require a status JSON reply, so
    // Prism is only opened once the server can actually answer a client.
    var py = [
      "import json, socket, struct, sys, time",
      "",
      "def varint(n):",
      "    out = b''",
      "    while True:",
      "        b = n & 0x7f",
      "        n >>= 7",
      "        out += bytes([b | (0x80 if n else 0)])",
      "        if not n:",
      "            return out",
      "",
      "def read_varint(buf, i):",
      "    val = 0",
      "    shift = 0",
      "    while True:",
      "        if i >= len(buf):",
      "            raise ValueError('short')",
      "        b = buf[i]",
      "        i += 1",
      "        val |= (b & 0x7f) << shift",
      "        if not (b & 0x80):",
      "            return val, i",
      "        shift += 7",
      "",
      "def probe(port):",
      "    s = socket.socket()",
      "    s.settimeout(3)",
      "    try:",
      "        s.connect(('127.0.0.1', port))",
      "        host = 'vember-hub'",
      "        hs = (varint(0) + varint(47) + varint(len(host)) +",
      "              host.encode() + struct.pack('>H', port) + varint(1))",
      "        s.sendall(varint(len(hs)) + hs + varint(1) + varint(0))",
      "        data = s.recv(65535)",
      "        if not data:",
      "            return False",
      "        _, i = read_varint(data, 0)",
      "        pid, i = read_varint(data, i)",
      "        if pid != 0:",
      "            return False",
      "        n, i = read_varint(data, i)",
      "        payload = data[i:i + n].decode('utf-8', 'replace')",
      "        return isinstance(json.loads(payload), dict)",
      "    except Exception:",
      "        return False",
      "    finally:",
      "        s.close()",
      "",
      "port, limit = int(sys.argv[1]), int(sys.argv[2])",
      "end = time.time() + limit",
      "while time.time() < end:",
      "    if probe(port):",
      "        print('ready')",
      "        sys.exit(0)",
      "    time.sleep(1)",
      "print('timeout')"
    ].join("\n");
    return ["python3", "-c", py, String(p), String(n)];
  }

  minecraftClientInstalled(apps) {
  var list = Array.isArray(apps) ? apps : [];
  for (var i = 0; i < list.length; i++) {
    if ((list[i] || {}).id === "prismlauncher" && list[i].installed)
      return true;
  }
  return false;
  }

  gameServerTotalBytes(sizes) {
  var list = Array.isArray(sizes) ? sizes : [];
  var total = 0;
  for (var i = 0; i < list.length; i++) {
    var n = Number((list[i] || {}).dataBytes);
    if (isFinite(n) && n > 0) total += n;
  }
  return total;
  }

  // One installed-game number for the Overview. Each library reports -1 until
  // its scan finishes, and a missing scan should not count as a game.
  totalInstalledGameCount(counts) {
  var c = counts || {};
  var keys = ["steam", "bnet", "prism", "heroic", "minecraft"];
  var total = 0;
  for (var i = 0; i < keys.length; i++) {
    var n = Number(c[keys[i]]);
    if (isFinite(n) && n > 0) total += Math.floor(n);
  }
  return total;
  }
}

const impl = new Gaming();

// Singleton shared with the other modules.
export const gaming = impl;
export function catalog(...args) { return impl.catalog(...args); }
export function scanCommand(...args) { return impl.scanCommand(...args); }
export function parseScan(...args) { return impl.parseScan(...args); }
export function defById(...args) { return impl.defById(...args); }
export function steamInstallCommand(...args) { return impl.steamInstallCommand(...args); }
export function battlenetSetupUrl(...args) { return impl.battlenetSetupUrl(...args); }
export function battlenetGameCountCommand(...args) { return impl.battlenetGameCountCommand(...args); }
export function parseBattlenetGameCount(...args) { return impl.parseBattlenetGameCount(...args); }
export function steamLibraryVdfPath(...args) { return impl.steamLibraryVdfPath(...args); }
export function battlenetPrefixPath(...args) { return impl.battlenetPrefixPath(...args); }
export function steamRootPath(...args) { return impl.steamRootPath(...args); }
export function parseLibraryPaths(...args) { return impl.parseLibraryPaths(...args); }
export function parseSteamManifestScan(...args) { return impl.parseSteamManifestScan(...args); }
export function steamManifestCountCommandForDirs(...args) { return impl.steamManifestCountCommandForDirs(...args); }
export function prismInstanceCountCommand(...args) { return impl.prismInstanceCountCommand(...args); }
export function parsePrismInstanceCount(...args) { return impl.parsePrismInstanceCount(...args); }
export function minecraftVersionCountCommand(...args) { return impl.minecraftVersionCountCommand(...args); }
export function parseMinecraftVersionCount(...args) { return impl.parseMinecraftVersionCount(...args); }
export function heroicGameCountCommand(...args) { return impl.heroicGameCountCommand(...args); }
export function parseHeroicGameCount(...args) { return impl.parseHeroicGameCount(...args); }
export function gameServerKeywords(...args) { return impl.gameServerKeywords(...args); }
export function gameServerContainers(...args) { return impl.gameServerContainers(...args); }
export function isMinecraftContainer(...args) { return impl.isMinecraftContainer(...args); }
export function minecraftServers(...args) { return impl.minecraftServers(...args); }
export function gameServerSizeCommand(...args) { return impl.gameServerSizeCommand(...args); }
export function parseGameServerSizes(...args) { return impl.parseGameServerSizes(...args); }
export function gameServerTotalBytes(...args) { return impl.gameServerTotalBytes(...args); }
export function totalInstalledGameCount(...args) { return impl.totalInstalledGameCount(...args); }
export function utf8Bytes(...args) { return impl.utf8Bytes(...args); }
export function minecraftServerListBytes(...args) { return impl.minecraftServerListBytes(...args); }
export function minecraftServerListCommand(...args) { return impl.minecraftServerListCommand(...args); }
export function minecraftJoinGameDirs(...args) { return impl.minecraftJoinGameDirs(...args); }
export function minecraftClientLaunchCommand(...args) { return impl.minecraftClientLaunchCommand(...args); }
export function minecraftInstanceId(...args) { return impl.minecraftInstanceId(...args); }
export function minecraftServerInstanceCommand(...args) { return impl.minecraftServerInstanceCommand(...args); }
export function minecraftPrismSetupCommand(...args) { return impl.minecraftPrismSetupCommand(...args); }
export function minecraftClientDefaultsCommand(...args) { return impl.minecraftClientDefaultsCommand(...args); }
export function parseMinecraftClientDefaults(...args) { return impl.parseMinecraftClientDefaults(...args); }
export function minecraftOfficialServerListCommand(...args) { return impl.minecraftOfficialServerListCommand(...args); }
export function minecraftOfficialLaunchCommand(...args) { return impl.minecraftOfficialLaunchCommand(...args); }
export function minecraftPortWaitCommand(...args) { return impl.minecraftPortWaitCommand(...args); }
export function minecraftClientInstalled(...args) { return impl.minecraftClientInstalled(...args); }
