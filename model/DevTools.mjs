// Developer tool detection, repo scanning and Code Server status.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `DevTools.name(...)` while tests use `new DevTools()`.

import { shell } from './Shell.mjs';

export class DevTools {
  checkCommand() {
  // Outputs lines: name\tinstalled\tpath\tversion
  var script = [
    // The panel does not inherit a login shell's PATH, so include the usual
    // per-user install dirs or uv/gh installed there look missing.
    "PATH=\"$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/pnpm:$PATH\"; export PATH;",
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

  parseChecks(text) {
  var out = [];
  var rows = shell.nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var parts = rows[i].split("\t");
    var name = shell.trim(parts[0] || "");
    if (!name) continue;
    out.push({
      id: name,
      installed: shell.trim(parts[1] || "") === "yes",
      path: shell.trim(parts[2] || ""),
      version: shell.trim(parts[3] || "")
    });
  }
  return out;
  }

  reposScanCommand(homeDir) {
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

  parseRepos(text) {
  var rows = shell.nonEmptyLines(text);
  var out = [];
  for (var i = 0; i < rows.length; i++) {
    var p = shell.trim(rows[i]);
    if (!p) continue;
    var name = p.split("/").pop() || p;
    out.push({ path: p, name: name });
  }
  return out;
  }

  repoDetailCommand(repoPath) {
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

  parseRepoDetail(text) {
  var out = { size: "", mtime: "", branch: "", dirty: "", remote: "", last: "", error: "" };
  var rows = shell.nonEmptyLines(text);
  for (var i = 0; i < rows.length; i++) {
    var line = rows[i];
    var idx = line.indexOf("\t");
    if (idx === -1) continue;
    var k = shell.trim(line.slice(0, idx));
    var v = shell.trim(line.slice(idx + 1));
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

  label(id) {
  if (id === "uv") return "uv";
  if (id === "python") return "Python";
  if (id === "gh") return "GitHub CLI";
  if (id === "zed") return "Zed";
  if (id === "vscode") return "VS Code";
  return String(id || "");
  }

  // The container and the config directory share one name. Renaming the
  // container without renaming the directory would strand the user's settings,
  // so every caller builds from this one value.
  codeServerContainer() {
  return "vember-code-server";
  }

  // The config directory as a shell fragment, for the setup script.
  codeServerConfigDir() {
  return "$HOME/.config/" + this.codeServerContainer();
  }

  codeServerPsCommand() {
  return ["sh", "-c", "docker ps -a --filter name=^/" + this.codeServerContainer()
    + "$ --format '{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Image}}' 2>/dev/null || true"];
  }

  parseCodeServerStatus(text) {
  var rows = shell.nonEmptyLines(text);
  if (rows.length === 0) return { present: false, running: false, state: "not found", status: "", image: "" };
  // take first matching line
  var parts = rows[0].split("\t");
  var state = shell.trim(parts[1] || "").toLowerCase();
  return {
    present: true,
    running: state === "running",
    state: state || "unknown",
    status: shell.trim(parts[2] || ""),
    image: shell.trim(parts[3] || "")
  };
  }
}

const impl = new DevTools();

// Singleton shared with the other modules.
export const devTools = impl;
export function checkCommand(...args) { return impl.checkCommand(...args); }
export function parseChecks(...args) { return impl.parseChecks(...args); }
export function reposScanCommand(...args) { return impl.reposScanCommand(...args); }
export function parseRepos(...args) { return impl.parseRepos(...args); }
export function repoDetailCommand(...args) { return impl.repoDetailCommand(...args); }
export function parseRepoDetail(...args) { return impl.parseRepoDetail(...args); }
export function label(...args) { return impl.label(...args); }
export function codeServerContainer(...args) { return impl.codeServerContainer(...args); }
export function codeServerPsCommand(...args) { return impl.codeServerPsCommand(...args); }
export function codeServerConfigDir(...args) { return impl.codeServerConfigDir(...args); }
export function parseCodeServerStatus(...args) { return impl.parseCodeServerStatus(...args); }
