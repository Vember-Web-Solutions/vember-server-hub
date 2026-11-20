// Filesystem, mount and process introspection.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `SystemInfo.name(...)` while tests use `new SystemInfo()`.

import { shell } from './Shell.mjs';

export class SystemInfo {
  findmntCommand(target) {
  return ["findmnt", "-nr", "-o", "SOURCE,TARGET,FSTYPE,LABEL,SIZE,USED,AVAIL,USE%", String(target)];
  }

  dfBytesCommand(target) {
  return ["df", "-B1", "-P", String(target)];
  }

  parseFindmnt(text) {
  // findmnt -nr -o SOURCE,TARGET,FSTYPE,LABEL,SIZE,USED,AVAIL,USE%
  var line = shell.nonEmptyLines(text)[0] || "";
  if (!line)
    return null;
  var parts = line.split(/\s+/);
  return {
    source: shell.trim(parts[0] || ""),
    target: shell.trim(parts[1] || "/mnt/games"),
    fstype: shell.trim(parts[2] || ""),
    label: shell.trim(parts[3] || ""),
    size: shell.trim(parts[4] || ""),
    used: shell.trim(parts[5] || ""),
    avail: shell.trim(parts[6] || ""),
    usePercent: shell.trim(parts[7] || "")
  };
  }

  parseDfBytes(text) {
  // df -B1 -P TARGET => header + one line: Filesystem 1B-blocks Used Available Use% Mounted
  var rows = shell.nonEmptyLines(text);
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
    usePercent: shell.trim(parts[4] || ""),
    target: parts.slice(5).join(" ")
  };
  }

  pgrepExactCommand(name) {
  return ["pgrep", "-x", String(name)];
  }
  // Host CPU utilisation from /proc/stat. Two samples 0.4s apart make a
  // percentage; psutil would do the same but is not installed here and a
  // dependency would break the portable hub on another user's machine.
  hostMetricsCommand() {
  var py = [
    "import json, time",
    "def sample():",
    "    vals = []",
    "    for line in open('/proc/stat'):",
    "        f = line.split()",
    "        if f and f[0] == 'cpu' and len(f) >= 5:",
    "            vals = [int(x) for x in f[1:5]]",
    "            break",
    "    return vals",
    "a = sample()",
    "time.sleep(0.4)",
    "b = sample()",
    "if len(a) < 4 or len(b) < 4:",
    "    print(json.dumps({'cpuPercent': -1}))",
    "else:",
    "    d = [max(0, y - x) for x, y in zip(a[:4], b[:4])]",
    "    total = sum(d)",
    "    pct = (100.0 * (total - d[3]) / total) if total > 0 else -1",
    "    print(json.dumps({'cpuPercent': round(pct, 1)}))"
  ].join("\n");
  return ["python3", "-c", py];
  }

  parseHostMetrics(text) {
  try {
    var m = JSON.parse(shell.trim(String(text || "")));
    var p = Number(m && m.cpuPercent);
    if (!isFinite(p) || p < 0 || p > 100) return { cpuPercent: -1 };
    return { cpuPercent: Math.round(p * 10) / 10 };
  } catch (e) {
    return { cpuPercent: -1 };
  }
  }

  // Storage pressure colour: green below 75%, amber from 75%, red from 90%.
  // A missing or unparseable ratio reads as 0% rather than as an error.
  storageUseColor(ratio) {
  var r = Number(ratio || 0);
  if (!isFinite(r)) r = 0;
  if (r >= 0.90) return "#ef4444";
  if (r >= 0.75) return "#eab308";
  return "#22c55e";
  }
}

const impl = new SystemInfo();

// Singleton shared with the other modules.
export const systemInfo = impl;
export function findmntCommand(...args) { return impl.findmntCommand(...args); }
export function dfBytesCommand(...args) { return impl.dfBytesCommand(...args); }
export function parseFindmnt(...args) { return impl.parseFindmnt(...args); }
export function parseDfBytes(...args) { return impl.parseDfBytes(...args); }
export function pgrepExactCommand(...args) { return impl.pgrepExactCommand(...args); }
export function hostMetricsCommand(...args) { return impl.hostMetricsCommand(...args); }
export function parseHostMetrics(...args) { return impl.parseHostMetrics(...args); }
export function storageUseColor(...args) { return impl.storageUseColor(...args); }
