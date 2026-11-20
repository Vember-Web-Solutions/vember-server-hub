// Guided Minecraft server creation.
//
// Everything the wizard asks — client choice, option lists, and the commands
// for preflight/install — lives here so QML and tests share one source of
// truth. Pure helpers only: no QML objects, no side effects.

import { shell } from './Shell.mjs';
import { Gaming } from './Gaming.mjs';

export class MinecraftWizard {
  // Step 1: which client will the operator use to join the server?
  clientOptions() {
    return [
      { value: "prism", label: "Prism Launcher", detail: "Instances, modpacks and one-click join" },
      { value: "official", label: "Official Minecraft Launcher", detail: "Mojang's standard launcher" }
    ];
  }

  // Step 2: how should the server process be run?
  runModeOptions() {
    return [
      { value: "docker", label: "Docker", detail: "The hub pulls the image and creates the container" },
      { value: "manual", label: "Run it myself", detail: "Show me the command to run by hand" }
    ];
  }

  // Step 3: the server options. Labels explain the trade-off so a first-time
  // user can finish the wizard without reading the image documentation.
  serverTypeOptions() {
    return [
      { value: "PAPER", label: "Paper — fast, plugin-friendly" },
      { value: "VANILLA", label: "Vanilla — plain Mojang server" },
      { value: "FORGE", label: "Forge — modded server" },
      { value: "FABRIC", label: "Fabric — modded server" }
    ];
  }

  versionOptions() {
    return [
      { value: "LATEST", label: "Latest (recommended)" },
      { value: "26.3", label: "26.3" },
      { value: "1.21.1", label: "1.21.1" },
      { value: "1.20.1", label: "1.20.1" }
    ];
  }

  memoryOptions() {
    return [
      { value: "2G", label: "2 GB — small vanilla worlds" },
      { value: "4G", label: "4 GB — recommended" },
      { value: "6G", label: "6 GB — modded servers" },
      { value: "8G", label: "8 GB — large modpacks" }
    ];
  }

  difficultyOptions() {
    return [
      { value: "PEACEFUL", label: "Peaceful" },
      { value: "EASY", label: "Easy" },
      { value: "NORMAL", label: "Normal" },
      { value: "HARD", label: "Hard" }
    ];
  }

  // Detects both clients in one pass. Output is id<TAB>0|1 per line, matching
  // the shape the hub's other app scans already use.
  clientCheckCommand() {
    return ["sh", "-c", [
      "has_cmd(){ command -v \"$1\" >/dev/null 2>&1; }",
      "has_flatpak(){ command -v flatpak >/dev/null 2>&1 && flatpak info \"$1\" >/dev/null 2>&1; }",
      "if has_cmd prismlauncher || has_flatpak org.prismlauncher.PrismLauncher; then p=1; else p=0; fi",
      "if has_cmd minecraft-launcher || has_flatpak com.mojang.Minecraft; then o=1; else o=0; fi",
      "printf 'prism\\t%s\\nofficial\\t%s\\n' \"$p\" \"$o\""
    ].join("\n")];
  }

  parseClientScan(text) {
    var found = { prism: false, official: false };
    shell.nonEmptyLines(text).forEach(function (line) {
      var parts = line.split("\t");
      var key = shell.trim(parts[0] || "");
      if (key === "prism" || key === "official")
        found[key] = shell.trim(parts[1] || "") === "1";
    });
    return found;
  }

  // Install commands mirror the launcher catalog. Prism is reused from there;
  // the official launcher is retired from the catalog but still an explicit
  // choice in this wizard, so it gets its own shell chain here.
  clientInstallCommand(client) {
    if (client === "official") {
      return ["sh", "-c",
        "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm minecraft-launcher; " +
        "elif command -v paru >/dev/null 2>&1; then paru -S --needed --noconfirm minecraft-launcher; " +
        "elif command -v flatpak >/dev/null 2>&1; then flatpak install -y flathub com.mojang.Minecraft; " +
        "else echo 'Install yay/paru or flatpak to install the official launcher.'; exit 1; fi"
      ];
    }
    var def = new Gaming().defById("prismlauncher");
    return ["sh", "-c", def && def.installCmd
      ? def.installCmd
      : "echo 'No supported installer found for Prism Launcher.'; exit 1"];
  }

  clientName(client) {
    return client === "official" ? "Official Minecraft Launcher" : "Prism Launcher";
  }
}

export function clientOptions(...args) { return new MinecraftWizard().clientOptions(...args); }
export function runModeOptions(...args) { return new MinecraftWizard().runModeOptions(...args); }
export function serverTypeOptions(...args) { return new MinecraftWizard().serverTypeOptions(...args); }
export function versionOptions(...args) { return new MinecraftWizard().versionOptions(...args); }
export function memoryOptions(...args) { return new MinecraftWizard().memoryOptions(...args); }
export function difficultyOptions(...args) { return new MinecraftWizard().difficultyOptions(...args); }
export function clientCheckCommand(...args) { return new MinecraftWizard().clientCheckCommand(...args); }
export function parseClientScan(...args) { return new MinecraftWizard().parseClientScan(...args); }
export function clientInstallCommand(...args) { return new MinecraftWizard().clientInstallCommand(...args); }
export function clientName(...args) { return new MinecraftWizard().clientName(...args); }
