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
export function storageUseColor(...args) { return impl.storageUseColor(...args); }
