// Docker command construction and `docker ps` parsing.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Docker.name(...)` while tests use `new Docker()`.

import { shell } from './Shell.mjs';

export class Docker {
  psCommand() {
  // Ports are in the same poll as names/states, so a container's web UI costs
  // no extra process. Labels are deliberately absent: they are long, noisy and
  // none of the local containers use reverse-proxy host rules.
  return ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.Ports}}"];
  }

  actionCommand(action, name) {
  return ["docker", String(action), String(name)];
  }

  pullCommand(image) {
  return ["docker", "pull", String(image)];
  }

  pruneCommand() {
  return ["docker", "container", "prune", "-f"];
  }

  parsePs(text) {
  var self = this;
  return shell.nonEmptyLines(text).map(function (line) {
    var parts = line.split("\t");
    var name = shell.trim(parts[0] || "");
    var image = shell.trim(parts[1] || "");
    var state = shell.trim(parts[2] || "").toLowerCase();
    var status = shell.trim(parts.slice(3).join("\t") || parts[2] || "");
    return {
      name: name,
      image: image,
      state: state || "unknown",
      status: status || state || "unknown",
      running: state === "running",
      ports: shell.trim(parts[4] || ""),
      webUrl: self.webUrlFromPorts(shell.trim(parts[4] || ""))
    };
  }).filter(function (row) { return row.name.length > 0; });
  }

  // One-shot memory snapshot. `docker stats --no-stream` exits, so it fits the
  // hub's process model without holding a stream open.
  statsCommand() {
  return ["docker", "stats", "--no-stream", "--format", "{{.Name}}\t{{.MemUsage}}"];
  }

  // MemUsage is "<used> / <limit>" per row. Only the used half is summed; a
  // row that cannot be parsed is skipped rather than blanking the whole card.
  parseStats(text) {
  var units = {
    b: 1, kib: 1024, mib: 1024 * 1024,
    gib: 1024 * 1024 * 1024, tib: 1024 * 1024 * 1024 * 1024
  };
  var bytes = 0;
  var count = 0;
  var rows = shell.nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var parts = rows[i].split("\t");
    var m = shell.trim(parts[1] || "").match(/^([\d.]+)\s*([A-Za-z]+)/);
    if (!m) continue;
    var factor = units[String(m[2]).toLowerCase()];
    var n = parseFloat(m[1]);
    if (!factor || !isFinite(n) || n < 0) continue;
    bytes += n * factor;
    count++;
  }
  return { totalBytes: Math.round(bytes), containers: count };
  }

  // Services that are never a browser page. Matching both the published and
  // the container-side port keeps a Minecraft/RDS container from growing a
  // misleading "Open" button while still allowing an arbitrary host port in
  // front of a real web app (15000->8000, 8610->8000, ...).
  nonWebPorts() {
  return [22, 25, 53, 110, 143, 1194, 3306, 3389, 5432, 5900, 6379, 25565, 27017, 51820];
  }

  // Host ports published by a container. Docker's Ports column mixes published
  // ports ("0.0.0.0:25565->25565/tcp", "[::]:25565->25565/tcp") with bare
  // container ports ("5432/tcp"); only the former reserve a host slot.
  publishedPorts(portsText) {
    var text = shell.trim(String(portsText || ""));
    var out = [];
    if (text.length === 0) return out;
    text.split(/[,\s]+/).forEach(function (entry) {
      var m = entry.match(/:(\d+)->\d+\/(?:tcp|udp)$/i);
      if (!m) return;
      var port = parseInt(m[1], 10);
      if (port > 0 && port <= 65535 && out.indexOf(port) === -1) out.push(port);
    });
    return out.sort(function (a, b) { return a - b; });
  }

  // Derive one browser URL from Docker's `Ports` column. Only published TCP
  // ports count; a bare "5432/tcp" is not reachable. Bind addresses are kept
  // only when they are literal IPs — wildcard and loopback become localhost,
  // and any other text is rejected rather than turned into a URL.
  webUrlFromPorts(portsText) {
  var text = shell.trim(String(portsText || ""));
  if (text.length === 0) return "";
  var blocked = this.nonWebPorts();
  var preferred = [443, 8443, 80, 8000, 8080, 3000, 5000];
  var entries = text.split(",");
  var fallback = "";
  var best = "";
  var bestRank = 99;
  for (var i = 0; i < entries.length; i++) {
    var part = shell.trim(entries[i]);
    var m = part.match(/^(?:\[([^\]]+)\]|([^:]+)):(\d+)->(\d+)\/(tcp|udp)$/i);
    if (!m || m[5].toLowerCase() !== "tcp") continue;
    var bind = m[1] || m[2] || "";
    var hostPort = parseInt(m[3], 10);
    var containerPort = parseInt(m[4], 10);
    if (!(hostPort > 0 && hostPort <= 65535)) continue;
    if (blocked.indexOf(hostPort) !== -1 || blocked.indexOf(containerPort) !== -1) continue;
    var host = "localhost";
    if (bind !== "0.0.0.0" && bind !== "::" && bind !== "127.0.0.1" && bind !== "::1") {
      if (/^\d{1,3}(\.\d{1,3}){3}$/.test(bind)) host = bind;
      else if (/^[0-9a-fA-F:]+$/.test(bind)) host = "[" + bind + "]";
      else continue;
    }
    var secure = containerPort === 443 || containerPort === 8443 ||
      hostPort === 443 || hostPort === 8443;
    var url = (secure ? "https" : "http") + "://" + host + ":" + hostPort;
    if (!fallback) fallback = url;
    var rank = preferred.indexOf(containerPort);
    if (rank < 0) rank = preferred.indexOf(hostPort);
    if (rank < 0) rank = 40;
    if (secure) rank -= 1;
    if (rank < bestRank) { bestRank = rank; best = url; }
  }
  return best || fallback;
  }

  // "12.3MB" / "1.5 GiB" / "900B" -> bytes. Returns NaN when unparseable so
  // callers can distinguish "no size" from "zero bytes".
  parseSize(text) {
  var m = String(text || "").trim().match(/^([0-9.]+)\s*([kKmMgGtT]?)(i?B)?$/);
  if (!m) return NaN;
  var n = parseFloat(m[1]);
  if (!isFinite(n)) return NaN;
  var u = (m[2] || "").toUpperCase();
  var mul = 1;
  if (u === "K") mul = 1024;
  else if (u === "M") mul = 1024 * 1024;
  else if (u === "G") mul = 1024 * 1024 * 1024;
  else if (u === "T") mul = 1024 * 1024 * 1024 * 1024;
  return n * mul;
  }

  // One line of `docker pull` progress. Returns null for lines that carry no
  // layer information, so callers can ignore them.
  parsePullLine(line) {
  var t = String(line || "");
  var m = t.match(/^([a-f0-9]+):\s+(Downloading|Extracting)\s+(?:\[[^\]]*\]\s*)?([0-9.]+\s*[kKmMgGtT]?i?B)\s*\/\s*([0-9.]+\s*[kKmMgGtT]?i?B)/);
  if (m) {
    return {
      id: m[1],
      phase: m[2].toLowerCase(),
      current: this.parseSize(m[3]),
      total: this.parseSize(m[4])
    };
  }
  if (/:\s+(Download complete|Pull complete|Already exists)/.test(t)) {
    var done = t.match(/^([a-f0-9]+):/);
    if (done) return { id: done[1], phase: "complete", current: null, total: null };
  }
  return null;
  }

  // Sum per-layer byte counters into one progress reading.
  accumulateLayers(layers) {
  var done = 0;
  var total = 0;
  var src = layers || {};
  for (var k in src) {
    if (!src.hasOwnProperty(k)) continue;
    var layer = src[k];
    if (layer && isFinite(layer.total) && layer.total > 0) {
      total += layer.total;
      done += Math.min(layer.current || 0, layer.total);
    }
  }
  return {
    done: done,
    total: total,
    progress: total > 0 ? Math.max(0, Math.min(1, done / total)) : 0
  };
  }
  // One data directory per server name. Two containers sharing a single /data
  // bind fight over world/session.lock and the second one never starts. The
  // name uses the same validation as the container name, so an edited or
  // half-typed value still maps to a safe, predictable path.
  minecraftDataDir(name, baseDir) {
  var base = shell.trim(String(baseDir || ""));
  if (base.charAt(0) !== "/" || base.indexOf("\n") !== -1)
    base = "/mnt/games/GameServers";
  var n = shell.trim(String(name || ""));
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$/.test(n))
    n = "vember-minecraft";
  return base.replace(/\/+$/, "") + "/" + n + "-data";
  }

  // Normalise the Minecraft create form before it reaches `docker run`. Every
  // field has a safe default so a blank or hand-edited input can never inject
  // extra arguments into the command array.
  normalizeMinecraftServerOptions(opts) {
  var o = opts || {};
  var name = shell.trim(String(o.name || ""));
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$/.test(name))
    name = "vember-minecraft";

  var type = String(o.type || "PAPER").toUpperCase();
  if (["VANILLA", "PAPER", "FORGE", "FABRIC"].indexOf(type) === -1)
    type = "PAPER";

  var version = shell.trim(String(o.version || "")).toUpperCase();
  if (!/^(LATEST|\d+\.\d+(\.\d+)?(?:-[A-Z0-9.]+)?)$/.test(version))
    version = "LATEST";

  var memory = shell.trim(String(o.memory || "")).toUpperCase();
  var mm = memory.match(/^(\d+)([MG])$/);
  if (!mm) {
    memory = "4G";
  } else {
    var amount = parseInt(mm[1], 10);
    var limit = mm[2] === "G" ? 32 : 32768;
    var floor = mm[2] === "G" ? 1 : 512;
    memory = (amount >= floor && amount <= limit) ? (amount + mm[2]) : "4G";
  }

  var difficulty = String(o.difficulty || "NORMAL").toUpperCase();
  if (["PEACEFUL", "EASY", "NORMAL", "HARD"].indexOf(difficulty) === -1)
    difficulty = "NORMAL";

  // Server worlds live one directory apart under the games mount, named after
  // the server (nodecraft -> .../nodecraft-data). Two containers sharing one
  // /data bind lock the same world and the second never starts, so the default
  // is derived from the name rather than fixed. An explicit dataDir still wins.
  var defaultDataDir = shell.trim(String(o.defaultDataDir || ""));
  if (defaultDataDir.charAt(0) !== "/" || defaultDataDir.indexOf("\n") !== -1)
    defaultDataDir = "/mnt/games/GameServers";
  var dataDir = shell.trim(String(o.dataDir || ""));
  if (dataDir.charAt(0) !== "/" || dataDir.indexOf("\n") !== -1)
    dataDir = this.minecraftDataDir(name, defaultDataDir);

  var port = Number(o.port);
  if (!isFinite(port) || port < 1 || port > 65535 || Math.floor(port) !== port)
    port = 25565;

  // Optional modpack sources. They are bind-mounted read-only by itzg: /mods
  // is copied into /data/mods, and WORLD clones the save into the data dir.
  // A colon would be read as a mount separator, so reject it here.
  function safeMountPath(value) {
    var p = shell.trim(String(value || ""));
    return (p.charAt(0) === "/" && p.indexOf("\n") === -1 && p.indexOf(":") === -1)
      ? p : "";
  }
  var modsDir = safeMountPath(o.modsDir);
  var worldDir = safeMountPath(o.worldDir);

  return {
    name: name, type: type, version: version,
    memory: memory, difficulty: difficulty, dataDir: dataDir, port: port,
    modsDir: modsDir, worldDir: worldDir
  };
  }

  // The itzg `:latest` tag now ships Java 25, which breaks older Minecraft
  // modpacks (1.18-era Fabric mixins and datapack registries fail to load).
  // Pick the JDK by game version: 1.20.5+ / 1.21+ need Java 21 and run fine on
  // :latest, while 1.17-1.20.4 need Java 17. LATEST stays on :latest.
  minecraftServerImage(version) {
  var v = shell.trim(String(version || "")).toUpperCase();
  if (v === "LATEST" || !v) return "itzg/minecraft-server:latest";
  var m = v.match(/^1\.(\d+)(?:\.(\d+))?/);
  if (!m) return "itzg/minecraft-server:latest";
  var minor = parseInt(m[1], 10);
  var patch = m[2] ? parseInt(m[2], 10) : 0;
  if (minor > 20 || (minor === 20 && patch >= 5))
    return "itzg/minecraft-server:latest";
  return "itzg/minecraft-server:java17";
  }

  // The wizard offers the itzg image as a guided route. These checks let it
  // explain a missing daemon or image before offering to pull it, instead of
  // failing halfway through `docker run`.
  minecraftServerImageCheckCommand(version) {
  return ["docker", "image", "inspect", this.minecraftServerImage(version)];
  }

  dockerReadyCommand() {
  return ["sh", "-c",
    "command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && echo ready || echo missing"];
  }

  // `docker run -d` prints the new container id and returns immediately. The
  // image then downloads the server jar, so "created" is the honest status —
  // the hub reports readiness from the container state on the next poll.
  // RCON stays inside the container; only the game port is published.
  createMinecraftServerCommand(opts) {
  var o = this.normalizeMinecraftServerOptions(opts);
  var cmd = [
    "docker", "run", "-d", "-it",
    "--name", o.name,
    "--restart", "unless-stopped",
    "-p", o.port + ":" + o.port,
    "-v", o.dataDir + ":/data",
    "-e", "EULA=TRUE",
    "-e", "TYPE=" + o.type,
    "-e", "VERSION=" + o.version,
    "-e", "MEMORY=" + o.memory,
    "-e", "DIFFICULTY=" + o.difficulty,
    // itzg listens on 25565 unless told otherwise. Without this, a server
    // published on 25566+ forwards to a port nothing is bound to and every
    // join is refused. The healthcheck follows SERVER_PORT too.
    "-e", "SERVER_PORT=" + o.port
  ];
  if (o.modsDir)
    cmd.push("-v", o.modsDir + ":/mods:ro");
  if (o.worldDir)
    cmd.push("-v", o.worldDir + ":/worlds/source:ro", "-e", "WORLD=/worlds/source");
  cmd.push(this.minecraftServerImage(o.version));
  return cmd;
  }

  // KubeJS modpacks (Create:Astral and friends) register a world's custom
  // biomes and dimensions from files under the instance's kubejs/config dirs.
  // itzg only receives /mods and the world, so such a world fails to load with
  // "Unbound values in registry ... worldgen/biome". Stage a copy into the
  // server's writable /data before `docker run`. Copy rather than bind mount:
  // KubeJS writes generated data back at boot, and the player's own instance
  // must never be changed by the server.
  stageModpackDataCommand(dataDir, supportDir) {
  var data = shell.trim(String(dataDir || ""));
  var src = shell.trim(String(supportDir || ""));
  if (data.charAt(0) !== "/" || data.indexOf("\n") !== -1 ||
      src.charAt(0) !== "/" || src.indexOf("\n") !== -1)
    return [];
  var lines = ["set -e"];
  var names = ["kubejs", "config", "defaultconfigs"];
  for (var i = 0; i < names.length; i++) {
    var from = shell.quote(src + "/" + names[i]);
    var to = shell.quote(data + "/" + names[i]);
    lines.push("if [ -d " + from + " ]; then mkdir -p " + to +
      "; cp -a " + from + "/. " + to + "/; fi");
  }
  return ["sh", "-c", lines.join("\n")];
  }

  logsCommand(name, lines) {
  var n = Math.floor(Number(lines));
  if (!isFinite(n) || n < 1 || n > 2000) n = 200;
  return ["docker", "logs", "--tail", String(n), shell.trim(String(name || ""))];
  }

  // Resolve the host path mounted at /data so "Open data folder" works for a
  // container created outside the hub too. Empty output means no such mount.
  inspectDataDirCommand(name) {
  return ["docker", "inspect", "--format",
    "{{range .Mounts}}{{if eq .Destination \"/data\"}}{{.Source}}{{end}}{{end}}",
    shell.trim(String(name || ""))];
  }

  // Remove one game server container and the host data dir the hub created for
  // it. The dialog is the operator's confirmation; this is still deliberately
  // narrow: only a /data mount whose basename is `<name>-data` is deleted. A
  // missing or unexpected mount refuses before the container is touched.
  removeGameServerCommand(name) {
  var target = shell.trim(String(name || ""));
  var script = [
    "set -eu",
    "name=$1",
    'case "$name" in',
    '  [A-Za-z0-9]*) ;;',
    '  *) echo "Refusing to remove unsafe container name: $name" >&2; exit 2 ;;',
    'esac',
    'case "$name" in',
    '  *[!A-Za-z0-9_.-]*) echo "Refusing to remove unsafe container name: $name" >&2; exit 2 ;;',
    'esac',
    "data=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/data\"}}{{.Source}}{{end}}{{end}}' \"$name\" 2>/dev/null || true)",
    "data=${data%/}",
    'case "$data" in',
    '  "") docker rm -f "$name" >/dev/null; echo "Removed container $name (no /data mount)."; exit 0 ;;',
    '  /*) ;;',
    '  *) echo "Refusing to delete non-absolute data path: $data" >&2; exit 2 ;;',
    'esac',
    'case "$data" in',
    '  /|/home|/root|/mnt|/mnt/games|/mnt/games/GameServers)',
    '    echo "Refusing to delete reserved data path: $data" >&2; exit 2 ;;',
    'esac',
    'case "$data" in',
    '  *"/.."|*"/../*"|*"/."|*"/./*"|*//*)',
    '    echo "Refusing to delete data path with traversal: $data" >&2; exit 2 ;;',
    'esac',
    'if [ "$(basename -- "$data")" != "$name-data" ]; then',
    '  echo "Refusing to delete unexpected data dir $data; expected $name-data" >&2; exit 2;',
    'fi',
    'if [ -L "$data" ]; then',
    '  echo "Refusing to delete symlinked data dir: $data" >&2; exit 2;',
    'fi',
    'docker rm -f "$name" >/dev/null',
    'if [ -d "$data" ]; then',
    '  if rm -rf -- "$data"; then',
    '    echo "Removed container $name and data dir $data";',
    '  else',
    '    echo "Container removed but data deletion failed: $data" >&2; exit 1;',
    '  fi',
    'else',
    '  echo "Removed container $name; data dir $data was already absent";',
    'fi'
  ].join("\n");
  return ["sh", "-c", script, "sh", target];
  }

  // Compose records its project, service and config files as container labels.
  // `|~|` is the separator: paths cannot contain it, unlike a tab which Go's
  // template escaping tends to mangle. All four fields come back in one
  // inspect so applying an update needs no extra round trips.
  inspectComposeCommand(name) {
  var n = shell.trim(String(name || ""));
  if (n.length === 0) return [];
  var label = function(key) {
    return '{{index .Config.Labels "' + key + '"}}';
  };
  var fields = [
    label("com.docker.compose.project.config_files"),
    label("com.docker.compose.project.working_dir"),
    label("com.docker.compose.project"),
    label("com.docker.compose.service")
  ];
  return ["docker", "inspect", "--format", fields.join("|~|"), n];
  }

  parseComposeInfo(text) {
  var t = shell.trim(String(text || ""));
  if (t.indexOf("|~|") === -1) return null;
  var parts = t.split("|~|");
  while (parts.length < 4) parts.push("");
  var files = shell.trim(parts[0]).split(",").map(function(f) {
    return shell.trim(f);
  }).filter(function(f) { return f.length > 0; });
  var workingDir = shell.trim(parts[1]);
  var project = shell.trim(parts[2]);
  var service = shell.trim(parts[3]);
  var safeName = /^[A-Za-z0-9][A-Za-z0-9_-]*$/;
  if (files.length === 0 || !safeName.test(project) || !safeName.test(service))
    return null;
  for (var i = 0; i < files.length; i++) {
    if (files[i].charAt(0) !== "/" || files[i].indexOf("\n") !== -1)
      return null;
  }
  if (workingDir.length > 0 && workingDir.charAt(0) !== "/") return null;
  return {
    files: files,
    workingDir: workingDir,
    project: project,
    service: service
  };
  }

  // `up -d --no-deps <service>` recreates only what the operator picked. The
  // values came from local Docker labels, but they are still validated above
  // and passed as argv — no interpolation into a shell string.
  applyComposeUpdateCommand(info) {
  var c = info || {};
  if (!Array.isArray(c.files) || c.files.length === 0) return [];
  var cmd = ["docker", "compose"];
  if (shell.trim(String(c.workingDir || "")).length > 0)
    cmd.push("--project-directory", c.workingDir);
  for (var i = 0; i < c.files.length; i++)
    cmd.push("-f", c.files[i]);
  return cmd.concat(["-p", c.project, "up", "-d", "--no-deps", c.service]);
  }

  // Colour for a container state. Null means "no opinion", so the caller can
  // fall back to the theme's muted colour instead of a hardcoded grey.
  stateTone(state) {
  var s = shell.trim(state).toLowerCase();
  if (s === "running") return "#22c55e";
  if (s === "restarting" || s === "paused" || s === "created") return "#eab308";
  if (s === "exited" || s === "dead" || s === "removing") return "#ef4444";
  return null;
  }

  // Background tint for the same states, as a CSS colour so it can be built
  // without a QML engine. The values match the previous Qt.rgba() calls.
  stateBackground(state) {
  var s = shell.trim(state).toLowerCase();
  if (s === "running") return "rgba(33, 196, 94, 0.18)";
  if (s === "restarting" || s === "paused" || s === "created") return "rgba(235, 179, 8, 0.18)";
  if (s === "exited" || s === "dead" || s === "removing") return "rgba(240, 69, 69, 0.18)";
  return null;
  }

  // How many containers are running. Malformed rows are skipped, not counted
  // as stopped.
  runningCount(containers) {
  var list = containers || [];
  var n = 0;
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].running) n++;
  }
  return n;
  }
}

const impl = new Docker();

// Singleton shared with the other modules.
export const docker = impl;
export function psCommand(...args) { return impl.psCommand(...args); }
export function actionCommand(...args) { return impl.actionCommand(...args); }
export function pullCommand(...args) { return impl.pullCommand(...args); }
export function pruneCommand(...args) { return impl.pruneCommand(...args); }
export function parsePs(...args) { return impl.parsePs(...args); }
export function statsCommand(...args) { return impl.statsCommand(...args); }
export function parseStats(...args) { return impl.parseStats(...args); }
export function minecraftDataDir(...args) { return impl.minecraftDataDir(...args); }
export function publishedPorts(...args) { return impl.publishedPorts(...args); }
export function webUrlFromPorts(...args) { return impl.webUrlFromPorts(...args); }
export function parseSize(...args) { return impl.parseSize(...args); }
export function parsePullLine(...args) { return impl.parsePullLine(...args); }
export function accumulateLayers(...args) { return impl.accumulateLayers(...args); }
export function normalizeMinecraftServerOptions(...args) { return impl.normalizeMinecraftServerOptions(...args); }
export function createMinecraftServerCommand(...args) { return impl.createMinecraftServerCommand(...args); }
export function stageModpackDataCommand(...args) { return impl.stageModpackDataCommand(...args); }
export function minecraftServerImage(...args) { return impl.minecraftServerImage(...args); }
export function dockerReadyCommand(...args) { return impl.dockerReadyCommand(...args); }
export function minecraftServerImageCheckCommand(...args) { return impl.minecraftServerImageCheckCommand(...args); }
export function logsCommand(...args) { return impl.logsCommand(...args); }
export function inspectDataDirCommand(...args) { return impl.inspectDataDirCommand(...args); }
export function removeGameServerCommand(...args) { return impl.removeGameServerCommand(...args); }
export function inspectComposeCommand(...args) { return impl.inspectComposeCommand(...args); }
export function parseComposeInfo(...args) { return impl.parseComposeInfo(...args); }
export function applyComposeUpdateCommand(...args) { return impl.applyComposeUpdateCommand(...args); }
export function stateTone(...args) { return impl.stateTone(...args); }
export function stateBackground(...args) { return impl.stateBackground(...args); }
export function runningCount(...args) { return impl.runningCount(...args); }
