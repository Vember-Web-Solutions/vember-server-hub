// Hub configuration helpers: tab ordering and defaults.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Config.name(...)` while tests use `new Config()`.

import { shell } from './Shell.mjs';

export const DEFAULT_TAB_ORDER = ["overview", "access", "containers", "games", "dev"];

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
}

const impl = new Config();

// Singleton shared with the other modules.
export const config = impl;
export function defaultTabOrder(...args) { return impl.defaultTabOrder(...args); }
export function normalizedTabOrder(...args) { return impl.normalizedTabOrder(...args); }
