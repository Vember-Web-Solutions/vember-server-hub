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
  var linesArr = nonEmptyLines(text);
  if (linesArr.length === 1) {
    var trimmed = trimText(linesArr[0]);
    if (/^\d+$/.test(trimmed))
      return Number(trimmed);
  }
  return linesArr.length;
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
    return ["python3", "-c", "print(0)"];
  var script = "import sys,glob,os,re\n" +
    "keep=0\n" +
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
    "    name=re.search(r'\"name\"\\s+\"([^\"]*)\"', t, re.I)\n" +
    "    n=(name.group(1) if name else '').lower()\n" +
    "    if ('proton' in n or 'steam linux runtime' in n or 'steamworks common redistributables' in n):\n" +
    "      continue\n" +
    "    keep+=1\n" +
    "print(keep)\n";
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

function devToolInstallCommand(id) {
  var cmd = "";
  if (id === "uv") cmd = "curl -LsSf https://astral.sh/uv/install.sh | sh";
  else if (id === "python") cmd = "sudo pacman -S --needed python python-pip";
  else if (id === "gh") cmd = "sudo pacman -S --needed github-cli";
  else if (id === "zed") cmd = "yay -S --needed zed-preview-bin || yay -S --needed zed || sudo pacman -S --needed zed";
  else if (id === "vscode") cmd = "yay -S --needed visual-studio-code-bin || sudo pacman -S --needed code";
  else cmd = "echo 'No install command configured for: " + String(id) + "'";
  return ["sh", "-c", "echo 'Install command:'; echo ''; echo " + JSON.stringify(cmd) + "; echo ''; eval " + JSON.stringify(cmd)];
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
