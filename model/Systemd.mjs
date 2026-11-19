// systemd unit queries and privileged actions.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Systemd.name(...)` while tests use `new Systemd()`.

export class Systemd {
  isActiveCommand(unit) {
  return ["systemctl", "is-active", String(unit)];
  }

  isEnabledCommand(unit) {
  return ["systemctl", "is-enabled", String(unit)];
  }

  pkexecCommand(action, unit) {
  return ["pkexec", "systemctl", String(action), String(unit)];
  }

  terminalCommand(action, unit) {
  return ["omarchy", "launch", "terminal", "sudo", "systemctl", String(action), String(unit)];
  }
}

const impl = new Systemd();

// Singleton shared with the other modules.
export const systemd = impl;
export function isActiveCommand(...args) { return impl.isActiveCommand(...args); }
export function isEnabledCommand(...args) { return impl.isEnabledCommand(...args); }
export function pkexecCommand(...args) { return impl.pkexecCommand(...args); }
export function terminalCommand(...args) { return impl.terminalCommand(...args); }
