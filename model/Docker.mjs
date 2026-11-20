// Docker command construction and `docker ps` parsing.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Docker.name(...)` while tests use `new Docker()`.

import { shell } from './Shell.mjs';

export class Docker {
  psCommand() {
  return ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}"];
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
      running: state === "running"
    };
  }).filter(function (row) { return row.name.length > 0; });
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

  var dataDir = shell.trim(String(o.dataDir || ""));
  if (dataDir.charAt(0) !== "/" || dataDir.indexOf("\n") !== -1)
    dataDir = "/mnt/games/MinecraftServer";

  var port = Number(o.port);
  if (!isFinite(port) || port < 1 || port > 65535 || Math.floor(port) !== port)
    port = 25565;

  return {
    name: name, type: type, version: version,
    memory: memory, dataDir: dataDir, port: port
  };
  }

  // `docker run -d` prints the new container id and returns immediately. The
  // image then downloads the server jar, so "created" is the honest status —
  // the hub reports readiness from the container state on the next poll.
  // RCON stays inside the container; only the game port is published.
  createMinecraftServerCommand(opts) {
  var o = this.normalizeMinecraftServerOptions(opts);
  return [
    "docker", "run", "-d", "-it",
    "--name", o.name,
    "--restart", "unless-stopped",
    "-p", o.port + ":" + o.port,
    "-v", o.dataDir + ":/data",
    "-e", "EULA=TRUE",
    "-e", "TYPE=" + o.type,
    "-e", "VERSION=" + o.version,
    "-e", "MEMORY=" + o.memory,
    "itzg/minecraft-server:latest"
  ];
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
export function parseSize(...args) { return impl.parseSize(...args); }
export function parsePullLine(...args) { return impl.parsePullLine(...args); }
export function accumulateLayers(...args) { return impl.accumulateLayers(...args); }
export function normalizeMinecraftServerOptions(...args) { return impl.normalizeMinecraftServerOptions(...args); }
export function createMinecraftServerCommand(...args) { return impl.createMinecraftServerCommand(...args); }
export function logsCommand(...args) { return impl.logsCommand(...args); }
export function inspectDataDirCommand(...args) { return impl.inspectDataDirCommand(...args); }
export function stateTone(...args) { return impl.stateTone(...args); }
export function stateBackground(...args) { return impl.stateBackground(...args); }
export function runningCount(...args) { return impl.runningCount(...args); }
