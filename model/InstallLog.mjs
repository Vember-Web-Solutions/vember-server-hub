// Install/update log paths, the terminal wrapper, and log parsing.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `InstallLog.name(...)` while tests use `new InstallLog()`.

import { shell } from './Shell.mjs';

export class InstallLog {
  cacheDir(homeDir) {
  return String(homeDir || "") + "/.cache/vember-server-hub";
  }

  logPath(homeDir) {
  return cacheDir(homeDir) + "/install.log";
  }

  titlePath(homeDir) {
  return cacheDir(homeDir) + "/install-title.txt";
  }

  lockPath(homeDir) {
  return cacheDir(homeDir) + "/install.lock";
  }

  omarchyLockPath(homeDir) {
  return cacheDir(homeDir) + "/omarchy-update.lock";
  }

  parse(text, limit) {
  var t = shell.stripAnsi(text);
  var rows = t.split("\n");
  var out = [];
  var finished = false;
  var exitCode = null;
  for (var i = 0; i < rows.length; i++) {
    var line = rows[i];
    var m = line.match(/\[vember-install-exit:(-?\d*)\]/);
    if (m) {
      finished = true;
      exitCode = (shell.trim(m[1]).length === 0 ? null : Number(m[1]));
      continue;
    }
    out.push(line);
  }
  while (out.length > 0 && shell.trim(out[0]).length === 0)
    out.shift();
  while (out.length > 0 && shell.trim(out[out.length - 1]).length === 0)
    out.pop();
  var joined = out.join("\n");
  var max = Number(limit || 12000);
  if (max > 0 && joined.length > max)
    joined = joined.slice(joined.length - max);
  return { text: joined, finished: finished, exitCode: exitCode };
  }

  terminalScript(title, cmd, logPath, titlePath, lockPath, id) {
  var dir = String(logPath).replace(/\/[^\/]*$/, "");
  var lock = String(lockPath || "");
  var lockStart = lock.length > 0
    ? "printf '%s\\n%s\\n' " + shell.quote(String(id || "")) + " \"$$\" > " + shell.quote(lock) + "; "
    : "";
  var lockEnd = lock.length > 0 ? "; rm -f " + shell.quote(lock) : "";
  var inner = lockStart + "( " + String(cmd || "") + " ) 2>&1 | tee " + shell.quote(logPath) +
    "; code=${PIPESTATUS[0]}; if [ -z \"$code\" ]; then code=1; fi" +
    "; echo \"[vember-install-exit:${code}]\" | tee -a " + shell.quote(logPath) +
    lockEnd +
    "; echo; echo 'Press Enter to close...'; read -r";
  return "mkdir -p " + shell.quote(dir) +
    " && printf '%s' " + shell.quote(title) + " > " + shell.quote(titlePath) +
    " && : > " + shell.quote(logPath) +
    " && { command -v xdg-terminal-exec >/dev/null 2>&1 || " +
    "{ echo 'xdg-terminal-exec not found; cannot open a terminal.' | tee -a " + shell.quote(logPath) +
    "; echo '[vember-install-exit:127]' | tee -a " + shell.quote(logPath) + "; exit 127; }; }" +
    " && xdg-terminal-exec --app-id=vember-install --title=" + shell.quote(title) +
    " bash -lc " + shell.quote(inner) +
    " </dev/null >/dev/null 2>&1 & " +
    "sleep 0.7; hyprctl dispatch focuswindow " + shell.quote("class:^(vember-install)$") +
    " >/dev/null 2>&1 || hyprctl dispatch focuswindow " + shell.quote("title:^(" + title + ")$") +
    " >/dev/null 2>&1 || hyprctl dispatch focuswindow " + shell.quote("title:" + title) +
    " >/dev/null 2>&1 || true";
  }
}

const impl = new InstallLog();

// Singleton shared with the other modules.
export const installLog = impl;
export function cacheDir(...args) { return impl.cacheDir(...args); }
export function logPath(...args) { return impl.logPath(...args); }
export function titlePath(...args) { return impl.titlePath(...args); }
export function lockPath(...args) { return impl.lockPath(...args); }
export function omarchyLockPath(...args) { return impl.omarchyLockPath(...args); }
export function parse(...args) { return impl.parse(...args); }
export function terminalScript(...args) { return impl.terminalScript(...args); }
