// Text, quoting and formatting helpers shared by every module.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Shell.name(...)` while tests use `new Shell()`.

export class Shell {
  trim(value) {
  return String(value === undefined || value === null ? "" : value).trim();
  }

  lines(text) {
  return trim(text).length === 0 ? [] : String(text).replace(/\r/g, "").split("\n");
  }

  nonEmptyLines(text) {
  return lines(text).map(function (line) { return trim(line); }).filter(function (line) { return line.length > 0; });
  }

  stripAnsi(text) {
  var t = String(text === undefined || text === null ? "" : text).replace(/\r/g, "");
  t = t.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
  t = t.replace(/\x1B\][^\x07]*(\x07|\x1B\\)/g, "");
  t = t.replace(/\x1B\[\?[0-9;]*[a-zA-Z]/g, "");
  return t;
  }

  quote(value) {
  return "'" + String(value === undefined || value === null ? "" : value).replace(/'/g, "'\\''") + "'";
  }

  safeName(value) {
  return trim(value);
  }

  statusLabel(ok, yesText, noText) {
  return ok ? yesText : noText;
  }

  humanBytes(bytes) {
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

  parseKeyValueLines(text) {
  var out = {};
  nonEmptyLines(text).forEach(function (line) {
    var idx = line.indexOf("=");
    if (idx === -1)
      idx = line.indexOf(":");
    if (idx === -1)
      return;
    var key = trim(line.slice(0, idx));
    var value = trim(line.slice(idx + 1));
    if (key.length > 0)
      out[key] = value;
  });
  return out;
  }
  // A one-line failure description. `what` is the whole phrase, so callers
  // keep their own wording. Commands collect stderr but a bare "(code 1)"
  // tells the user nothing, so the first meaningful stderr line is folded in
  // when there is one.
  failureMessage(what, code, stderr) {
  var base = String(what) + " (code " + code + ")";
  var detail = trim(stderr || "");
  if (detail.length === 0) return base + ".";
  var first = nonEmptyLines(detail)[0] || detail;
  return base + ": " + trim(first) + ".";
  }
}

const impl = new Shell();

// Singleton shared with the other modules.
export const shell = impl;
export function trim(...args) { return impl.trim(...args); }
export function lines(...args) { return impl.lines(...args); }
export function nonEmptyLines(...args) { return impl.nonEmptyLines(...args); }
export function stripAnsi(...args) { return impl.stripAnsi(...args); }
export function quote(...args) { return impl.quote(...args); }
export function safeName(...args) { return impl.safeName(...args); }
export function statusLabel(...args) { return impl.statusLabel(...args); }
export function humanBytes(...args) { return impl.humanBytes(...args); }
export function parseKeyValueLines(...args) { return impl.parseKeyValueLines(...args); }
export function failureMessage(...args) { return impl.failureMessage(...args); }
