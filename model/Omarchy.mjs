// Omarchy system update commands.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Omarchy.name(...)` while tests use `new Omarchy()`.

export class Omarchy {
  updateTerminalCommand() {
  return ["/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation", "/usr/share/omarchy/bin/omarchy-update"];
  }
}

const impl = new Omarchy();

// Singleton shared with the other modules.
export const omarchy = impl;
export function updateTerminalCommand(...args) { return impl.updateTerminalCommand(...args); }
