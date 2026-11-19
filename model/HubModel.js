.pragma library

function trimText(value) {
  return String(value === undefined || value === null ? "" : value).trim();
}

function lines(text) {
  return trimText(text).length === 0 ? [] : String(text).replace(/\r/g, "").split("\n");
}

function nonEmptyLines(text) {
  return lines(text).map(function (line) { return trimText(line); }).filter(function (line) { return line.length > 0; });
}

function parseDockerPs(text) {
  return nonEmptyLines(text).map(function (line) {
    var parts = line.split("\t");
    var name = trimText(parts[0] || "");
    var image = trimText(parts[1] || "");
    var state = trimText(parts[2] || "").toLowerCase();
    var status = trimText(parts.slice(3).join("\t") || parts[2] || "");
    return {
      name: name,
      image: image,
      state: state || "unknown",
      status: status || state || "unknown",
      running: state === "running"
    };
  }).filter(function (row) { return row.name.length > 0; });
}

function parseKeyValueLines(text) {
  var out = {};
  nonEmptyLines(text).forEach(function (line) {
    var idx = line.indexOf("=");
    if (idx === -1)
      idx = line.indexOf(":");
    if (idx === -1)
      return;
    var key = trimText(line.slice(0, idx));
    var value = trimText(line.slice(idx + 1));
    if (key.length > 0)
      out[key] = value;
  });
  return out;
}

function parseFindmnt(text) {
  // findmnt -nr -o SOURCE,TARGET,FSTYPE,LABEL,SIZE,USED,AVAIL,USE%
  var line = nonEmptyLines(text)[0] || "";
  if (!line)
    return null;
  var parts = line.split(/\s+/);
  return {
    source: trimText(parts[0] || ""),
    target: trimText(parts[1] || "/mnt/games"),
    fstype: trimText(parts[2] || ""),
    label: trimText(parts[3] || ""),
    size: trimText(parts[4] || ""),
    used: trimText(parts[5] || ""),
    avail: trimText(parts[6] || ""),
    usePercent: trimText(parts[7] || "")
  };
}

function parseDfBytes(text) {
  // df -B1 -P TARGET => header + one line: Filesystem 1B-blocks Used Available Use% Mounted
  var rows = nonEmptyLines(text);
  if (rows.length < 2)
    return null;
  var parts = rows[rows.length - 1].trim().split(/\s+/);
  if (parts.length < 6)
    return null;
  return {
    filesystem: parts[0],
    totalBytes: Number(parts[1] || 0),
    usedBytes: Number(parts[2] || 0),
    availBytes: Number(parts[3] || 0),
    usePercent: trimText(parts[4] || ""),
    target: parts.slice(5).join(" ")
  };
}

function humanBytes(bytes) {
  var n = Number(bytes || 0);
  if (!isFinite(n) || n <= 0)
    return "0 B";
  var units = ["B", "KiB", "MiB", "GiB", "TiB"];
  var i = 0;
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024;
    i += 1;
  }
  var digits = i <= 1 ? 0 : (n >= 100 ? 0 : 1);
  return n.toFixed(digits) + " " + units[i];
}

function parsePgrepCount(text) {
  return nonEmptyLines(text).length;
}

function parseManifestCount(text) {
  var scan = parseSteamManifestScan(text);
  return scan.count;
}

function parseSteamManifestScan(text) {
  var t = trimText(text);
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
            appid: trimText(srv.appid || ""),
            name: trimText(srv.name || ""),
            installdir: trimText(srv.installdir || "")
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
  var rows = nonEmptyLines(t);
  if (rows.length === 1 && /^\d+$/.test(trimText(rows[0]))) {
    out.count = Number(trimText(rows[0]));
    return out;
  }
  out.count = rows.length;
  return out;
}

function parseLibraryPathsFromVdf(text) {
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

function dockerPsCommand() {
  return ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}"];
}

function dockerActionCommand(action, name) {
  return ["docker", String(action), String(name)];
}

function dockerPullCommand(image) {
  return ["docker", "pull", String(image)];
}

function dockerPruneCommand() {
  return ["docker", "container", "prune", "-f"];
}

function tailscaleStatusCommand() {
  return ["tailscale", "status", "--self=false"];
}

function tailscaleStatusJsonCommand() {
  return ["tailscale", "status", "--json"];
}

function parseTailscaleStatusJson(text) {
  var out = {
    ok: false,
    tailnetName: "",
    magicDnsSuffix: "",
    backendState: "",
    self: null,
    peers: []
  };
  var raw = trimText(text);
  if (raw.length === 0)
    return out;
  try {
    var d = JSON.parse(raw);
    out.ok = true;
    out.backendState = trimText(d.BackendState || "");
    out.magicDnsSuffix = trimText(d.MagicDNSSuffix || (d.CurrentTailnet && d.CurrentTailnet.MagicDNSSuffix) || "");
    var ctName = trimText((d.CurrentTailnet && d.CurrentTailnet.Name) || "");
    out.tailnetName = out.magicDnsSuffix || ctName;
    var self = d.Self || null;
    if (self) {
      out.self = {
        hostName: trimText(self.HostName || ""),
        dnsName: trimText(self.DNSName || "").replace(/\.$/, ""),
        ips: Array.isArray(self.TailscaleIPs) ? self.TailscaleIPs : [],
        os: trimText(self.OS || ""),
        online: self.Online === true,
        active: self.Active === true,
        isSelf: true
      };
    }
    var peersObj = d.Peer || {};
    var keys = Object.keys(peersObj);
    for (var i = 0; i < keys.length; i++) {
      var p = peersObj[keys[i]] || {};
      out.peers.push({
        hostName: trimText(p.HostName || ""),
        dnsName: trimText(p.DNSName || "").replace(/\.$/, ""),
        ips: Array.isArray(p.TailscaleIPs) ? p.TailscaleIPs : [],
        os: trimText(p.OS || ""),
        online: p.Online === true,
        active: p.Active === true,
        lastSeen: trimText(p.LastSeen || ""),
        isSelf: false
      });
    }
    out.peers.sort(function (a, b) {
      if (a.online !== b.online) return a.online ? -1 : 1;
      return String(a.hostName || a.dnsName).toLowerCase().localeCompare(String(b.hostName || b.dnsName).toLowerCase());
    });
  } catch (e) {
    out.ok = false;
  }
  return out;
}

function tailscaleIpCommand() {
  return ["tailscale", "ip", "-4"];
}

function systemctlIsActiveCommand(unit) {
  return ["systemctl", "is-active", String(unit)];
}

function systemctlIsEnabledCommand(unit) {
  return ["systemctl", "is-enabled", String(unit)];
}

function pkexecSystemctlCommand(action, unit) {
  return ["pkexec", "systemctl", String(action), String(unit)];
}

function terminalSystemctlCommand(action, unit) {
  return ["omarchy", "launch", "terminal", "sudo", "systemctl", String(action), String(unit)];
}

function omarchyUpdateTerminalCommand() {
  return ["/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation", "/usr/share/omarchy/bin/omarchy-update"];
}

function findmntCommand(target) {
  return ["findmnt", "-nr", "-o", "SOURCE,TARGET,FSTYPE,LABEL,SIZE,USED,AVAIL,USE%", String(target)];
}

function dfBytesCommand(target) {
  return ["df", "-B1", "-P", String(target)];
}

function pgrepExactCommand(name) {
  return ["pgrep", "-x", String(name)];
}

function steamManifestCountCommand(steamappsDir) {
  return ["find", String(steamappsDir), "-maxdepth", "1", "-name", "appmanifest_*.acf"];
}

function steamManifestCountCommandForDirs(steamappsDirs) {
  var dirs = Array.isArray(steamappsDirs) ? steamappsDirs : [];
  var filtered = [];
  for (var i = 0; i < dirs.length; i++) {
    if (trimText(dirs[i]).length > 0)
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

function battlenetGameCountCommand(homeDir) {
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

function parseBattlenetGameCount(text) {
  var paths = nonEmptyLines(text);
  var seen = {};
  var count = 0;
  for (var i = 0; i < paths.length; i++) {
    var p = trimText(paths[i]);
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

function steamLibraryVdfPath(homeDir) {
  return String(homeDir || "") + "/.local/share/Steam/steamapps/libraryfolders.vdf";
}

function battlenetPrefixPath(homeDir) {
  return String(homeDir || "") + "/Games/battlenet";
}

function steamRootPath(homeDir) {
  return String(homeDir || "") + "/.local/share/Steam";
}

function sshHostKeyFingerprintsCommand() {
  return ["sh", "-c", "for f in /etc/ssh/ssh_host_*key.pub; do [ -f \"$f\" ] || continue; ssh-keygen -lf \"$f\" 2>/dev/null || true; done"];
}

function parseSshHostKeyFingerprints(text) {
  var out = [];
  var rows = nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var line = rows[i];
    // e.g. 256 SHA256:... comment (ED25519)
    var m = /^(\d+)\s+(\S+)\s+(.*)\s+\(([^)]+)\)\s*$/.exec(line);
    if (m) {
      out.push({
        bits: trimText(m[1]),
        fingerprint: trimText(m[2]),
        comment: trimText(m[3]),
        type: trimText(m[4])
      });
    }
  }
  return out;
}

function authorizedKeysPath(homeDir) {
  return String(homeDir || "") + "/.ssh/authorized_keys";
}

function authorizedKeysReadCommand(homeDir) {
  var path = authorizedKeysPath(homeDir);
  return ["sh", "-c", "if [ -f \"$1\" ]; then cat \"$1\"; fi", "sh", path];
}

function parseAuthorizedKeys(text) {
  var out = [];
  var rawLines = String(text || "").replace(/\r/g, "").split("\n");
  // if file ends with newline, split gives trailing empty string; keep line numbers aligned
  for (var i = 0; i < rawLines.length; i++) {
    var line = rawLines[i];
    if (i === rawLines.length - 1 && line === "")
      continue;
    var t = trimText(line);
    if (t.length === 0 || t.charAt(0) === "#")
      continue;
    var parts = t.split(/\s+/);
    var type = "";
    var keyData = "";
    var comment = "";
    // handle optional options prefix (starts with command=, from=, etc. or quoted) - best effort: find token starting with ssh-/ecdsa-/sk-
    var keyIdx = -1;
    for (var j = 0; j < parts.length; j++) {
      if (/^(ssh-|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)/.test(parts[j])) {
        keyIdx = j;
        break;
      }
    }
    if (keyIdx >= 0 && keyIdx + 1 < parts.length) {
      type = parts[keyIdx];
      keyData = parts[keyIdx + 1];
      comment = parts.slice(keyIdx + 2).join(" ");
    } else if (parts.length >= 2) {
      type = parts[0];
      keyData = parts[1];
      comment = parts.slice(2).join(" ");
    } else {
      type = "unknown";
      keyData = t;
      comment = "";
    }
    var preview = keyData.length > 24 ? (keyData.slice(0, 12) + "…" + keyData.slice(-8)) : keyData;
    out.push({
      lineNo: i + 1,
      line: line,
      type: type,
      keyData: keyData,
      keyPreview: preview,
      comment: comment
    });
  }
  return out;
}

function safeName(value) {
  return trimText(value);
}

function statusLabel(ok, yesText, noText) {
  return ok ? yesText : noText;
}

function devToolCheckCommand() {
  // Outputs lines: name\tinstalled\tpath\tversion
  var script = [
    "check(){ n=\"$1\"; shift; p=\"\"; v=\"\"; for c in \"$@\"; do if command -v \"$c\" >/dev/null 2>&1; then p=$(command -v \"$c\"); break; fi; done;",
    "if [ -n \"$p\" ]; then",
    "  case \"$n\" in",
    "    uv) v=$(uv --version 2>/dev/null | head -n1 || true);;",
    "    python) v=$(python3 --version 2>/dev/null || python --version 2>/dev/null || true);;",
    "    gh) v=$(gh --version 2>/dev/null | head -n1 || true);;",
    "    zed) v=$(zed --version 2>/dev/null | head -n1 || zeditor --version 2>/dev/null | head -n1 || true);;",
    "    vscode) v=$(code --version 2>/dev/null | head -n1 || code-oss --version 2>/dev/null | head -n1 || true);;",
    "  esac;",
    "  printf '%s\\t%s\\t%s\\t%s\\n' \"$n\" yes \"$p\" \"$v\";",
    "else",
    "  printf '%s\\t%s\\t%s\\t%s\\n' \"$n\" no \"\" \"\";",
    "fi; };",
    "check uv uv;",
    "check python python3 python;",
    "check gh gh;",
    "check zed zed zeditor;",
    "check vscode code code-oss"
  ].join(" ");
  return ["sh", "-c", script];
}

function parseDevToolChecks(text) {
  var out = [];
  var rows = nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var parts = rows[i].split("\t");
    var name = trimText(parts[0] || "");
    if (!name) continue;
    out.push({
      id: name,
      installed: trimText(parts[1] || "") === "yes",
      path: trimText(parts[2] || ""),
      version: trimText(parts[3] || "")
    });
  }
  return out;
}

function devReposScanCommand(homeDir) {
  var h = String(homeDir || "");
  var script = [
    "h=\"$1\";",
    "for d in \"$h/Projects\" \"$h/projects\" \"$h/Code\" \"$h/code\" \"$h/src\" \"$h/dev\" \"$h/repos\" \"$h/git\"; do",
    "  [ -d \"$d\" ] || continue;",
    "  find \"$d\" -mindepth 2 -maxdepth 4 -name .git -type d 2>/dev/null;",
    "done | sed 's#/.git$##' | sort -u"
  ].join(" ");
  return ["sh", "-c", script, "sh", h];
}

function parseDevRepos(text) {
  var rows = nonEmptyLines(text);
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    var p = trimText(rows[i]);
    if (!p) continue;
    var name = p.split("/").pop() || p;
    out.push({ path: p, name: name });
  }
  return out;
}

function devRepoDetailCommand(repoPath) {
  var p = String(repoPath || "");
  var script = [
    "p=\"$1\"",
    "if [ ! -d \"$p\" ]; then echo 'ERR\tNot a directory'; exit 0; fi",
    "size=$(du -sh \"$p\" 2>/dev/null | awk '{print $1}' || true)",
    "mtime=$(stat -c '%y' \"$p\" 2>/dev/null | cut -d'.' -f1 || true)",
    "branch=''; dirty=''; remote=''; last=''",
    "if [ -d \"$p/.git\" ] || git -C \"$p\" rev-parse --git-dir >/dev/null 2>&1; then",
    "  branch=$(git -C \"$p\" rev-parse --abbrev-ref HEAD 2>/dev/null || true)",
    "  dc=$(git -C \"$p\" status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo 0)",
    "  if [ \"${dc:-0}\" = \"0\" ]; then dirty='clean'; else dirty=\"$dc change(s)\"; fi",
    "  remote=$(git -C \"$p\" remote get-url origin 2>/dev/null || true)",
    "  last=$(git -C \"$p\" log -1 --format='%cs %s' 2>/dev/null || true)",
    "fi",
    "printf 'SIZE\\t%s\\n' \"$size\"",
    "printf 'MTIME\\t%s\\n' \"$mtime\"",
    "printf 'BRANCH\\t%s\\n' \"$branch\"",
    "printf 'DIRTY\\t%s\\n' \"$dirty\"",
    "printf 'REMOTE\\t%s\\n' \"$remote\"",
    "printf 'LAST\\t%s\\n' \"$last\""
  ].join("\n");
  return ["sh", "-c", script, "sh", p];
}

function parseDevRepoDetail(text) {
  var out = { size: "", mtime: "", branch: "", dirty: "", remote: "", last: "", error: "" };
  var rows = nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var line = rows[i];
    var idx = line.indexOf("\t");
    if (idx === -1) continue;
    var k = trimText(line.slice(0, idx));
    var v = trimText(line.slice(idx + 1));
    if (k === "SIZE") out.size = v;
    else if (k === "MTIME") out.mtime = v;
    else if (k === "BRANCH") out.branch = v;
    else if (k === "DIRTY") out.dirty = v;
    else if (k === "REMOTE") out.remote = v;
    else if (k === "LAST") out.last = v;
    else if (k === "ERR") out.error = v;
  }
  return out;
}

function devToolLabel(id) {
  if (id === "uv") return "uv";
  if (id === "python") return "Python";
  if (id === "gh") return "GitHub CLI";
  if (id === "zed") return "Zed";
  if (id === "vscode") return "VS Code";
  return String(id || "");
}

function codeServerContainerName() {
  return "vember-code-server";
}

function codeServerPsCommand() {
  return ["sh", "-c", "docker ps -a --filter name=^/vember-code-server$ --format '{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}' 2>/dev/null || true"];
}

function parseCodeServerStatus(text) {
  var rows = nonEmptyLines(text);
  if (rows.length === 0) return { present: false, running: false, state: "not found", status: "", image: "" };
  // take first matching line
  var parts = rows[0].split("\t");
  var state = trimText(parts[1] || "").toLowerCase();
  return {
    present: true,
    running: state === "running",
    state: state || "unknown",
    status: trimText(parts[2] || ""),
    image: trimText(parts[3] || "")
  };
}

function extraAppsCatalog() {
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
      name: "Discord",
      description: "Voice, video, and text chat.",
      category: "apps",
      icon: "file:///usr/share/icons/hicolor/256x256/apps/discord.png",
      launchCmd: ["sh", "-c", "command -v discord >/dev/null 2>&1 && exec discord || command -v Discord >/dev/null 2>&1 && exec Discord || exec flatpak run com.discordapp.Discord"],
      installCmd: "if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm discord; elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.discordapp.Discord; else echo 'No supported installer found for Discord.'; exit 1; fi"
    }
  ];
}

function extraAppsScanCommand() {
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
    "if has_cmd discord || has_cmd Discord || has_flatpak com.discordapp.Discord; then idc=1; else idc=0; fi; if running_any discord Discord; then rdc=1; else rdc=0; fi; emit discord \"$idc\" \"$rdc\" ''"
  ].join("\n");
  return ["sh", "-c", script];
}

function parseExtraAppsScan(text, catalog) {
  var byId = {};
  var rows = nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var parts = rows[i].split("\t");
    var id = trimText(parts[0] || "");
    if (!id) continue;
    byId[id] = {
      installed: trimText(parts[1] || "0") === "1",
      running: trimText(parts[2] || "0") === "1",
      note: trimText(parts.slice(3).join("\t") || "")
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

function extraAppDefById(id) {
  var cat = extraAppsCatalog();
  for (var i = 0; i < cat.length; i++) {
    if (cat[i] && cat[i].id === id) return cat[i];
  }
  return null;
}

// --- Install runner helpers -------------------------------------------------
// Shared by launcher/app installs and dev-tool terminal installs.

function stripAnsi(text) {
  var t = String(text === undefined || text === null ? "" : text).replace(/\r/g, "");
  t = t.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
  t = t.replace(/\x1B\][^\x07]*(\x07|\x1B\\)/g, "");
  t = t.replace(/\x1B\[\?[0-9;]*[a-zA-Z]/g, "");
  return t;
}

function installCacheDir(homeDir) {
  return String(homeDir || "") + "/.cache/vember-server-hub";
}

function installLogPath(homeDir) {
  return installCacheDir(homeDir) + "/install.log";
}

function installTitlePath(homeDir) {
  return installCacheDir(homeDir) + "/install-title.txt";
}

// Written by the install terminal itself (line 1: id, line 2: pid) so the
// panel can reattach to an install that outlived the panel being closed.
function installLockPath(homeDir) {
  return installCacheDir(homeDir) + "/install.lock";
}

// Parses a captured install log. Returns the visible text plus the exit marker
// state written by the terminal wrapper: [vember-install-exit:<code>]
function parseInstallLog(text, limit) {
  var t = stripAnsi(text);
  var rows = t.split("\n");
  var out = [];
  var finished = false;
  var exitCode = null;
  for (var i = 0; i < rows.length; i++) {
    var line = rows[i];
    var m = line.match(/\[vember-install-exit:(-?\d*)\]/);
    if (m) {
      finished = true;
      exitCode = (trimText(m[1]).length === 0 ? null : Number(m[1]));
      continue;
    }
    out.push(line);
  }
  while (out.length > 0 && trimText(out[0]).length === 0)
    out.shift();
  while (out.length > 0 && trimText(out[out.length - 1]).length === 0)
    out.pop();
  var joined = out.join("\n");
  var max = Number(limit || 12000);
  if (max > 0 && joined.length > max)
    joined = joined.slice(joined.length - max);
  return { text: joined, finished: finished, exitCode: exitCode };
}

// Builds the shell script that opens the default terminal, tees output to the
// log file, records the exit code marker, and tries to focus the new window.
function shellQuote(value) {
  return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
}

// Builds the shell script that opens the default terminal, tees output to the
// log file, records the exit code marker, and tries to focus the new window.
// Values are single-quoted so the outer shell cannot expand ${PIPESTATUS[...]}.
function installTerminalScript(title, cmd, logPath, titlePath, lockPath, id) {
  var dir = String(logPath).replace(/\/[^\/]*$/, "");
  var lock = String(lockPath || "");
  var lockStart = lock.length > 0
    ? "printf '%s\\n%s\\n' " + shellQuote(String(id || "")) + " \"$$\" > " + shellQuote(lock) + "; "
    : "";
  var lockEnd = lock.length > 0 ? "; rm -f " + shellQuote(lock) : "";
  var inner = lockStart + "( " + String(cmd || "") + " ) 2>&1 | tee " + shellQuote(logPath) +
    "; code=${PIPESTATUS[0]}; if [ -z \"$code\" ]; then code=1; fi" +
    "; echo \"[vember-install-exit:${code}]\" | tee -a " + shellQuote(logPath) +
    lockEnd +
    "; echo; echo 'Press Enter to close...'; read -r";
  return "mkdir -p " + shellQuote(dir) +
    " && printf '%s' " + shellQuote(title) + " > " + shellQuote(titlePath) +
    " && : > " + shellQuote(logPath) +
    " && { command -v xdg-terminal-exec >/dev/null 2>&1 || " +
    "{ echo 'xdg-terminal-exec not found; cannot open a terminal.' | tee -a " + shellQuote(logPath) +
    "; echo '[vember-install-exit:127]' | tee -a " + shellQuote(logPath) + "; exit 127; }; }" +
    " && xdg-terminal-exec --app-id=vember-install --title=" + shellQuote(title) +
    " bash -lc " + shellQuote(inner) +
    " </dev/null >/dev/null 2>&1 & " +
    "sleep 0.7; hyprctl dispatch focuswindow " + shellQuote("class:^(vember-install)$") +
    " >/dev/null 2>&1 || hyprctl dispatch focuswindow " + shellQuote("title:^(" + title + ")$") +
    " >/dev/null 2>&1 || hyprctl dispatch focuswindow " + shellQuote("title:" + title) +
    " >/dev/null 2>&1 || true";
}

function steamInstallCommand() {
  return "if command -v pacman >/dev/null 2>&1; then sudo pacman -S --needed --noconfirm steam; " +
    "elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.valvesoftware.Steam; " +
    "else echo 'No supported installer found for Steam.'; exit 1; fi";
}

function battlenetSetupUrl() {
  return "https://lutris.net/games/battlenet/";
}
