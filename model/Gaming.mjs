// Launcher/app catalog, Steam and Battle.net helpers.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Gaming.name(...)` while tests use `new Gaming()`.

import { shell } from './Shell.mjs';

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
      id: "minecraft-launcher",
      name: "Minecraft Launcher",
      description: "Official Minecraft launcher (AUR/flatpak depending on setup).",
      category: "minecraft",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/minecraft-launcher.png",
      launchCmd: ["sh", "-c", "command -v minecraft-launcher >/dev/null 2>&1 && exec minecraft-launcher || exec flatpak run com.mojang.Minecraft"],
      installCmd: "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm minecraft-launcher; elif command -v paru >/dev/null 2>&1; then paru -S --needed --noconfirm minecraft-launcher; elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.mojang.Minecraft; else echo 'Install yay/paru or flatpak to install Minecraft Launcher.'; exit 1; fi"
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
    // minecraft-launcher
    "if has_cmd minecraft-launcher || has_flatpak com.mojang.Minecraft; then im=1; else im=0; fi; if running_any minecraft-launcher; then rm=1; else rm=0; fi; emit minecraft-launcher \"$im\" \"$rm\" ''",
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
