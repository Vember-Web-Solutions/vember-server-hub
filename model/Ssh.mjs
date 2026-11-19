// SSH host keys and authorized_keys helpers.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Ssh.name(...)` while tests use `new Ssh()`.

import { shell } from './Shell.mjs';

export class Ssh {
  hostKeyFingerprintsCommand() {
  return ["sh", "-c", "for f in /etc/ssh/ssh_host_*key.pub; do [ -f \"$f\" ] || continue; ssh-keygen -lf \"$f\" 2>/dev/null || true; done"];
  }

  parseHostKeyFingerprints(text) {
  var out = [];
  var rows = shell.nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var line = rows[i];
    // e.g. 256 SHA256:... comment (ED25519)
    var m = /^(\d+)\s+(\S+)\s+(.*)\s+\(([^)]+)\)\s*$/.exec(line);
    if (m) {
      out.push({
        bits: shell.trim(m[1]),
        fingerprint: shell.trim(m[2]),
        comment: shell.trim(m[3]),
        type: shell.trim(m[4])
      });
    }
  }
  return out;
  }

  authorizedKeysPath(homeDir) {
  return String(homeDir || "") + "/.ssh/authorized_keys";
  }

  authorizedKeysReadCommand(homeDir) {
  var path = authorizedKeysPath(homeDir);
  return ["sh", "-c", "if [ -f \"$1\" ]; then cat \"$1\"; fi", "sh", path];
  }

  parseAuthorizedKeys(text) {
  var out = [];
  var rawLines = String(text || "").replace(/\r/g, "").split("\n");
  // if file ends with newline, split gives trailing empty string; keep line numbers aligned
  for (var i = 0; i < rawLines.length; i++) {
    var line = rawLines[i];
    if (i === rawLines.length - 1 && line === "")
      continue;
    var t = shell.trim(line);
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
}

const impl = new Ssh();

// Singleton shared with the other modules.
export const ssh = impl;
export function hostKeyFingerprintsCommand(...args) { return impl.hostKeyFingerprintsCommand(...args); }
export function parseHostKeyFingerprints(...args) { return impl.parseHostKeyFingerprints(...args); }
export function authorizedKeysPath(...args) { return impl.authorizedKeysPath(...args); }
export function authorizedKeysReadCommand(...args) { return impl.authorizedKeysReadCommand(...args); }
export function parseAuthorizedKeys(...args) { return impl.parseAuthorizedKeys(...args); }
