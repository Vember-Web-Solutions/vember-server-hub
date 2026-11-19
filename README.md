# Vember Server Hub

A local server hub plugin for [Omarchy](https://omarchy.org/) (Quickshell shell). It adds a panel and bar widget for monitoring and managing a Linux server from your desktop: access, containers, development tools, gaming, and storage in one place.

## Features

- **Overview** — server name/role summary, Tailnet and SSH status chips, and at-a-glance cards linking into each area; inner **Overview | Update** tabs with the Omarchy update action and its live log. The log persists, and if you reopen the panel mid-update it reattaches to the running update instead of offering a second one.
- **Access** — Tailnet (Tailscale) status/details and SSH info with authorized key management (view/add/remove/generate identity), organized in inner tabs.
- **Containers** — Docker container list and details with actionable controls; on-demand container size info and pull/progress feedback where available.
- **Dev**
  - **Workspace** — scanned repositories with a details panel (folder size, git branch/status, remote, last commit) and open-in-editor support.
  - **Tools** — detect/install common dev tools (e.g. `uv`, `python`, `gh`, editors) and choose a preferred local editor.
  - **Code Server (Docker)** — guided setup/start/stop/open/uninstall flow for `codercom/code-server` with configurable host port/password handling, progress/debug output, persistent mounts, and provisioning for a Python workspace (including `python3`/`pip`/`venv`, `uv`, `gh`, and recommended VS Code extensions).
- **Gaming** — launchers, apps, game server containers (best-effort detection), and game/storage partition status in inner tabs.
- **Interactive installs** — launcher/app/tool installs open in your default terminal (so sudo password and y/n prompts work), stream live output into the hub, and report the real exit code. Install logs persist across panel close/reload in `~/.cache/vember-server-hub/install.log`, and a lock file lets the panel reattach to an install that is still running when you reopen it. If the terminal never opens, the hub says so instead of hanging; if output goes quiet it checks whether the terminal is still alive (a password prompt never reaches the log) and only stops tracking when the process is really gone.
- **Panel UX** — reorderable/persisted tabs, settings/arrange dialogs, toasts, fullscreen toggle, and a first-run wizard for server identity/role.

> Feature availability depends on what is installed and configured on the host (Docker, Tailscale, SSH, game launchers, dev tools, etc.). Detection is best-effort.

## Requirements

- **Omarchy** with the Quickshell-based Omarchy shell (this plugin provides `panel` and `bar-widget` entry points).
- Optional, depending on features used:
  - **Docker** — Containers tab and Code Server (Docker)
  - **Tailscale** — Tailnet status/details
  - **OpenSSH / systemd** — SSH status and key management
  - **Dev tools** — `git`, `uv`, `python3`, `gh`, `zed`/`zeditor`, `code` as desired

## Install

### From a local checkout (development/symlink)

Clone or place this repository on disk, then symlink it into your Omarchy plugins directory:

```bash
mkdir -p ~/.config/omarchy/plugins
ln -sfn /path/to/vember-server ~/.config/omarchy/plugins/elena.vember-server-hub
```

Reload the shell if needed (the plugin UI hot-reloads in many cases, but backend/state changes may require a shell/hub reload).

### From Git (recommended for users)

Once the repository is hosted publicly, install with Omarchy’s plugin tooling:

```bash
omarchy plugin add https://github.com/Vember-Web-Solutions/vember-server-hub.git
# optionally enable/placement prompts follow; or use --enable / --yes
```

To validate a local copy before publishing or installing:

```bash
omarchy plugin validate /path/to/vember-server
```

## Configuration & data

- **Plugin config:** `~/.config/omarchy/plugins/elena.vember-server-hub/config.json` (local to the machine; gitignored in this repo). Stores server name/role, preferences, tab order, wizard state, and related settings.
- **Code Server (Docker):** setup creates/uses `~/.config/vember-code-server/` for config, user data, bin mounts, and a restricted env file for the password (not stored in plain text in `config.yaml`). Default workspace helpers may be created under `~/Projects` (e.g. `vember-python.code-workspace`, `.vscode/` recommendations/settings) when missing.
- **Secrets:** do not commit local config, tokens, or passwords. The included `.gitignore` excludes `config.json`.
- **Logs:** `~/.cache/vember-server-hub/` holds the Omarchy update log and the shared install log used by the live log views.

## Development

- **Plugin ID:** `elena.vember-server-hub` (see `manifest.json`)
- **Entry points:** `Panel.qml` (backend/controller), `BarWidget.qml` (bar icon)
- **UI:** `HubPanel.qml` is the panel shell; each tab lives in `ui/tabs/` and each dialog/overlay in `ui/`
- **Model:** `model/*.mjs` holds the pure helpers as ES classes (`Shell`, `Docker`, `Gaming`, `DevTools`, `InstallLog`, `Config`, ...). QML imports the namespace and calls `Shell.trim(...)`; tests instantiate the class directly.
- **Tests:** `./tests/run.sh` — creates a venv outside the plugin folder (Omarchy rejects symlinks inside plugins) and drives the real ES modules through node, so the suite exercises the same code QML loads.
- **Manifest:** tracks `version` and `build` in `manifest.json`
- QML/JS edits often hot-reload; backend/process logic changes may require reloading the Omarchy shell/hub.
- After cloning/customizing, you can rescan plugins with `omarchy-shell shell rescanPlugins` if changes don’t appear.

## Publishing to Omarchy

Omarchy plugins are distributed as git repositories with a valid `manifest.json`. To share this plugin:

1. **Validate:** run `omarchy plugin validate .` from the repo root and fix any issues.
2. **Publish a public git repo** (e.g. on GitHub) with `manifest.json`, entry points, and assets included; keep local-only files (like `config.json`) out of git.
3. **Install/test:** others can add it via `omarchy plugin add <git-url>` (and enable/place the bar widget as prompted).
4. **Community/catalog:** if Omarchy maintains a community plugin listing/catalog, follow its submission process for that catalog (check current Omarchy docs/community channels for the preferred way to get listed).

## License

MIT — see [LICENSE](LICENSE).
