// Tailscale status queries and JSON parsing.
//
// Pure helpers only: no QML objects, no side effects. The class is
// instantiated once and re-exported as plain functions so QML can call
// `Tailscale.name(...)` while tests use `new Tailscale()`.

import { shell } from './Shell.mjs';

export class Tailscale {
  statusCommand() {
  return ["tailscale", "status", "--self=false"];
  }

  statusJsonCommand() {
  return ["tailscale", "status", "--json"];
  }

  ipCommand() {
  return ["tailscale", "ip", "-4"];
  }

  parseStatusJson(text) {
  var out = {
    ok: false,
    tailnetName: "",
    magicDnsSuffix: "",
    backendState: "",
    self: null,
    peers: []
  };
  var raw = shell.trim(text);
  if (raw.length === 0)
    return out;
  try {
    var d = JSON.parse(raw);
    out.ok = true;
    out.backendState = shell.trim(d.BackendState || "");
    out.magicDnsSuffix = shell.trim(d.MagicDNSSuffix || (d.CurrentTailnet && d.CurrentTailnet.MagicDNSSuffix) || "");
    var ctName = shell.trim((d.CurrentTailnet && d.CurrentTailnet.Name) || "");
    out.tailnetName = out.magicDnsSuffix || ctName;
    var self = d.Self || null;
    if (self) {
      out.self = {
        hostName: shell.trim(self.HostName || ""),
        dnsName: shell.trim(self.DNSName || "").replace(/\.$/, ""),
        ips: Array.isArray(self.TailscaleIPs) ? self.TailscaleIPs : [],
        os: shell.trim(self.OS || ""),
        online: self.Online === true,
        active: self.Active === true,
        isSelf: true
      };
    }
    var peersObj = d.Peer || {};
    var keys = Object.keys(peersObj);
    for (var i = 0; i < keys.length; i++) {
      var p = peersObj[keys[i]] || {};
      out.peers.push({
        hostName: shell.trim(p.HostName || ""),
        dnsName: shell.trim(p.DNSName || "").replace(/\.$/, ""),
        ips: Array.isArray(p.TailscaleIPs) ? p.TailscaleIPs : [],
        os: shell.trim(p.OS || ""),
        online: p.Online === true,
        active: p.Active === true,
        lastSeen: shell.trim(p.LastSeen || ""),
        isSelf: false
      });
    }
    out.peers.sort(function (a, b) {
      if (a.online !== b.online) return a.online ? -1 : 1;
      return String(a.hostName || a.dnsName).toLowerCase().localeCompare(String(b.hostName || b.dnsName).toLowerCase());
    });
  } catch (e) {
    out.ok = false;
  }
  return out;
  }
}

const impl = new Tailscale();

// Singleton shared with the other modules.
export const tailscale = impl;
export function statusCommand(...args) { return impl.statusCommand(...args); }
export function statusJsonCommand(...args) { return impl.statusJsonCommand(...args); }
export function ipCommand(...args) { return impl.ipCommand(...args); }
export function parseStatusJson(...args) { return impl.parseStatusJson(...args); }
