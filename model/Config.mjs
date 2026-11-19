// Hub configuration helpers: tab ordering and defaults.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Config.name(...)` while tests use `new Config()`.

import { shell } from './Shell.mjs';

export const DEFAULT_TAB_ORDER = ["overview", "access", "containers", "games", "dev"];

// Label and icon for each tab. Kept here rather than in QML so the tab strip
// and anything that lists tabs read from one table.
export const TAB_DEFS = {
  overview: { id: "overview", label: "Overview", icon: "󰕮" },
  access: { id: "access", label: "Access", icon: "󰖂" },
  containers: { id: "containers", label: "Containers", icon: "󰡨" },
  games: { id: "games", label: "Gaming", icon: "󰊴" },
  dev: { id: "dev", label: "Dev", icon: "󰅨" }
};

export class Config {
  defaultTabOrder() {
  return DEFAULT_TAB_ORDER.slice();
  }

  // Accept whatever was saved on disk, drop anything unknown or duplicated,
  // then append the tabs that are missing. The result is always the full set,
  // so adding a new tab does not require a config migration.
  normalizedTabOrder(order) {
  var defaults = DEFAULT_TAB_ORDER;
  var out = [];
  var seen = {};
  var src = order || [];
  for (var i = 0; i < src.length; i++) {
    var id = shell.trim(src[i]);
    if (defaults.indexOf(id) !== -1 && !seen[id]) {
      seen[id] = true;
      out.push(id);
    }
  }
  for (var j = 0; j < defaults.length; j++) {
    if (!seen[defaults[j]]) out.push(defaults[j]);
  }
  return out;
  }

  // The label and icon for one tab. An unknown id gets a neutral fallback so a
  // stale config can never produce an empty tab.
  tabDef(id) {
  var def = TAB_DEFS[id];
  if (def) return { id: def.id, label: def.label, icon: def.icon };
  return { id: id, label: id, icon: "󰘔" };
  }

  // The tab strip, in the saved order, as ready-to-render definitions.
  orderedTabs(order) {
  var list = this.normalizedTabOrder(order);
  var out = [];
  for (var i = 0; i < list.length; i++) out.push(this.tabDef(list[i]));
  return out;
  }

  // Turn the contents of config.json into the fields the panel needs.
  //
  // The four outcomes are deliberately distinct, because the panel treats
  // them differently:
  //
  //   "empty"   no file yet            - keep editor/order/port, ask for a name
  //   "ready"   a name is configured   - use everything, no wizard
  //   "wizard"  file exists, no name   - use editor/order/port, ask for a name
  //   "invalid" unreadable JSON        - reset to defaults, ask for a name
  //
  // Returning the state rather than booleans keeps the QML side a plain
  // switch, and lets tests cover every branch without a running shell.
  parseHubConfig(raw) {
  var text = shell.trim(raw);
  if (text.length === 0) {
    return { state: "empty" };
  }

  var obj;
  try {
    obj = JSON.parse(text);
  } catch (e) {
    return {
      state: "invalid",
      serverName: "",
      serverRole: "",
      preferredEditor: "",
      tabOrder: this.normalizedTabOrder([]),
      codeServerPort: 8443
    };
  }

  // JSON.parse("[]") and JSON.parse("null") both succeed without producing a
  // config object, so they are treated as corrupt rather than as an empty file.
  if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
    return {
      state: "invalid",
      serverName: "",
      serverRole: "",
      preferredEditor: "",
      tabOrder: this.normalizedTabOrder([]),
      codeServerPort: 8443
    };
  }

  var name = shell.trim(obj.serverName ? obj.serverName : "");
  var role = shell.trim(obj.serverRole ? obj.serverRole : "");
  var editor = shell.trim(obj.preferredEditor ? obj.preferredEditor : "");
  var order = this.normalizedTabOrder(obj.tabOrder ? obj.tabOrder : []);

  // A port outside the valid range is a typo, not a preference: fall back to
  // the default rather than refusing to start the container.
  var port = Number(obj.codeServerPort ? obj.codeServerPort : 8443);
  if (!isFinite(port)) port = 8443;
  port = Math.round(port);
  if (port < 1 || port > 65535) port = 8443;

  return {
    state: name.length > 0 ? "ready" : "wizard",
    serverName: name,
    serverRole: role,
    preferredEditor: editor,
    tabOrder: order,
    codeServerPort: port
  };
  }
  // Swap one entry with its neighbour. Returns a new array; when the move would
  // fall off either end the contents are unchanged, so callers can assign the
  // result unconditionally.
  moveTab(order, index, delta) {
  var next = (order || []).slice(0);
  var j = index + delta;
  if (index < 0 || j < 0 || index >= next.length || j >= next.length) return next;
  var tmp = next[index];
  next[index] = next[j];
  next[j] = tmp;
  return next;
  }
}

const impl = new Config();

// Singleton shared with the other modules.
export const config = impl;
export function defaultTabOrder(...args) { return impl.defaultTabOrder(...args); }
export function normalizedTabOrder(...args) { return impl.normalizedTabOrder(...args); }
export function parseHubConfig(...args) { return impl.parseHubConfig(...args); }
export function tabDef(...args) { return impl.tabDef(...args); }
export function orderedTabs(...args) { return impl.orderedTabs(...args); }
export function moveTab(...args) { return impl.moveTab(...args); }
