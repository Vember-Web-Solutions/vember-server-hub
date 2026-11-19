// Hyprland window focus.
//
// Hyprland 0.56 evaluates `hyprctl dispatch <arg>` as `hl.dispatch(<arg>)`, so
// the long-standing `hyprctl dispatch focuswindow 'class:^name$'` argument is a
// Lua syntax error and the call fails. The supported form is a dispatcher
// object:
//
//     hyprctl dispatch 'hl.dsp.focus({window="class:vember-install"})'
//
// That call exits 0 whether or not it found a window — a miss prints
// "window not found" instead — so an `||` chain cannot tell success from
// failure and the fallback selectors would never run. Success is read from the
// output. The legacy form is still tried afterwards for older Hyprland builds.
//
// Pure helpers only: no QML objects, no side effects. The class is instantiated
// once and re-exported as plain functions so QML can call `Hypr.name(...)`
// while tests use `new Hypr()`.

import { shell } from './Shell.mjs';

export class Hypr {
  // A self-contained shell snippet. `selectors` are Hyprland window selectors
  // in priority order; the first that reports "ok" wins. Returns "true" when
  // there is nothing to try, so it can always be spliced into a command chain.
  focusScript(selectors) {
    var list = Array.isArray(selectors) ? selectors : [];
    var calls = [];
    for (var i = 0; i < list.length; i++) {
      var selector = shell.trim(list[i]);
      if (selector.length > 0)
        calls.push("focus_win " + shell.quote(selector));
    }
    if (calls.length === 0)
      return "true";
    var fn = [
      "focus_win() {",
      "sel=\"$1\";",
      "expr=$(printf 'hl.dsp.focus({window=\"%s\"})' \"$sel\");",
      "out=$(hyprctl dispatch \"$expr\" 2>&1);",
      "case \"$out\" in *ok*) return 0 ;; esac;",
      "hyprctl dispatch focuswindow \"$sel\" >/dev/null 2>&1 && return 0;",
      "return 1;",
      "}"
    ].join(" ");
    return "command -v hyprctl >/dev/null 2>&1 && { " + fn + "; " +
      calls.join(" || ") + " || true; }";
  }

  // Class first, then the anchored title, then the bare title: the window may
  // still be mapping when the focus runs, and a launcher can override the class.
  focusByClassScript(className, title) {
    var selectors = [];
    var cls = shell.trim(className);
    if (cls.length > 0)
      selectors.push("class:" + cls);
    var name = shell.trim(title);
    if (name.length > 0) {
      selectors.push("title:^(" + name + ")$");
      selectors.push("title:" + name);
    }
    return this.focusScript(selectors);
  }
}

const impl = new Hypr();

// Singleton shared with the other modules.
export const hypr = impl;
export function focusScript(...args) { return impl.focusScript(...args); }
export function focusByClassScript(...args) { return impl.focusByClassScript(...args); }
