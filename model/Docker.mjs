// Docker command construction and `docker ps` parsing.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Docker.name(...)` while tests use `new Docker()`.

import { shell } from './Shell.mjs';

export class Docker {
  psCommand() {
  return ["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}"];
  }

  actionCommand(action, name) {
  return ["docker", String(action), String(name)];
  }

  pullCommand(image) {
  return ["docker", "pull", String(image)];
  }

  pruneCommand() {
  return ["docker", "container", "prune", "-f"];
  }

  parsePs(text) {
  return shell.nonEmptyLines(text).map(function (line) {
    var parts = line.split("\t");
    var name = shell.trim(parts[0] || "");
    var image = shell.trim(parts[1] || "");
    var state = shell.trim(parts[2] || "").toLowerCase();
    var status = shell.trim(parts.slice(3).join("\t") || parts[2] || "");
    return {
      name: name,
      image: image,
      state: state || "unknown",
      status: status || state || "unknown",
      running: state === "running"
    };
  }).filter(function (row) { return row.name.length > 0; });
  }
}

const impl = new Docker();

// Singleton shared with the other modules.
export const docker = impl;
export function psCommand(...args) { return impl.psCommand(...args); }
export function actionCommand(...args) { return impl.actionCommand(...args); }
export function pullCommand(...args) { return impl.pullCommand(...args); }
export function pruneCommand(...args) { return impl.pruneCommand(...args); }
export function parsePs(...args) { return impl.parsePs(...args); }
