import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import "model/DevTools.mjs" as DevTools
import "model/Config.mjs" as Config
import "model/Docker.mjs" as Docker
import "model/Gaming.mjs" as Gaming
import "model/InstallLog.mjs" as InstallLog
import "model/Shell.mjs" as Shell
import "model/Ssh.mjs" as Ssh
import "model/SystemInfo.mjs" as SystemInfo
import "model/Systemd.mjs" as Systemd
import "model/Tailscale.mjs" as Tailscale

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property var targetScreen: null

  readonly property string pluginId: manifest && manifest.id ? manifest.id : "elena.vember-server-hub"
  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string gameMount: "/mnt/games"
  readonly property string configPath: homeDir + "/.config/omarchy/plugins/elena.vember-server-hub/config.json"

  property string pluginVersion: manifest && manifest.version ? String(manifest.version) : "0.6.1"
  property int pluginBuild: manifest && manifest.build ? Number(manifest.build) : 77
  property string serverName: ""
  property string serverNameDraft: ""
  property string serverRole: ""
  property string serverRoleDraft: ""
  property string preferredEditor: ""
  property var tabOrder: Config.defaultTabOrder()
  property bool configReady: false
  property bool wizardOpen: false
  property bool restartingForServerName: false
  property bool pendingConfigRestart: false
  property bool updateAvailable: false
  property string updateAvailableBuild: ""
  property bool updateCheckBusy: false
  property bool pluginUpdateBusy: false
  property int pluginUpdateRemoteCommits: 0
  property string pluginUpdateError: ""
  property string pluginUpdatePun: ""
  property string pluginUpdateStatus: ""
  property real pluginUpdateProgress: 0
  property string pluginRepoDir: ""

  property string tailscaleActive: "unknown"
  property string tailscaleEnabled: "unknown"
  property string tailscaleIp: ""
  property string tailscaleStatusText: ""
  property string tailscaleNote: ""
  property bool tailscaleBusy: false
  property string tailscaleTailnetName: ""
  property var tailscaleSelf: null
  property var tailscalePeers: []

  property var dockerContainers: []
  property string dockerError: ""
  property bool dockerBusy: false
  property string dockerBusyName: ""
  property bool dockerPullActive: false
  property string dockerPullingName: ""
  property string dockerPullingImage: ""
  property string dockerPullStatus: ""
  property real dockerPullPercent: -1
  property string dockerPullResult: ""
  property bool dockerPruneBusy: false
  property string dockerDetailSizeName: ""
  property string dockerDetailSizeText: ""
  property bool dockerDetailSizeBusy: false
  property string dockerDetailSizeError: ""

  property bool steamInstalled: false
  property bool steamRunning: false
  property int steamGameCount: -1
  property var steamDedicatedServers: []
  property string steamNote: ""

  property bool bnetInstalled: false
  property bool bnetRunning: false
  property int bnetGameCount: -1
  property string bnetNote: ""

  property var extraApps: []
  property bool extraAppsScanBusy: false
  property string extraAppInstallStatus: ""

  // Shared install runner (launchers/apps + dev tool terminal installs)
  property bool installRunning: false
  property string installRunningId: ""
  property string installTitle: ""
  property string installLog: ""
  readonly property bool installIsDev: installRunningId.indexOf("dev:") === 0

  property bool gameMountPresent: false
  property string gameMountSummary: ""
  property string gameMountError: ""
  property real gameMountUseRatio: 0
  property double gameMountUsedBytes: 0
  property double gameMountAvailBytes: 0
  property double gameMountTotalBytes: 0
  property string gameMountUsePercentText: ""

  property string lastActionMessage: ""

  property bool omarchyUpdateRunning: false
  property string omarchyUpdateStatus: ""
  property string omarchyUpdateLog: ""

  property string sshActive: "unknown"
  property string sshEnabled: "unknown"
  property var sshHostKeys: []
  property string sshHostName: ""

  property var sshAuthorizedKeys: []
  property int sshSelectedKeyIndex: -1
  property string sshNewKeyText: ""
  property string sshAuthorizedKeysStatus: ""
  property string sshGeneratedPublicKey: ""
  property bool sshGenerateBusy: false

  property var devTools: []
  property var devRepos: []
  property bool devBusy: false
  property string devStatus: ""
  property string devError: ""
  property bool devInstallBusy: false
  property string devInstallToolId: ""
  property string devInstallStatus: ""
  property bool devToolsOnlyRefresh: false
  property string devSelectedRepoPath: ""
  property var devRepoDetail: ({})
  property bool devRepoDetailBusy: false

  property bool codeServerPresent: false
  property bool codeServerRunning: false
  property string codeServerState: "unknown"
  property string codeServerStatusText: ""
  property string codeServerImage: ""
  property bool codeServerBusy: false
  property int codeServerPort: 8443
  property string codeServerSetupStage: ""
  property string codeServerSetupDetail: ""
  property real codeServerSetupProgress: -1
  property int codeServerSetupPollsLeft: 0
  property string codeServerSetupLog: ""
  property double codeServerSetupBytesDone: 0
  property double codeServerSetupBytesTotal: 0
  property var _codeServerPullLayers: ({})
  property bool codeServerSetupProvisionAfterStart: false

  // --- Panel lifecycle and IPC ---
  function open(payloadJson) {
    if (Quickshell.screens && Quickshell.screens.length > 0)
      root.targetScreen = Quickshell.screens[0];
    else
      root.targetScreen = null;
    root.opened = true;
    loadManifestInfo();
    loadHubConfig();
    refreshAll();
  }

  function close() {
    root.opened = false;
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function")
      shell.hide(pluginId);
    else
      root.opened = false;
  }

  function status() {
    return JSON.stringify({
      opened: root.opened,
      serverName: root.serverName,
      tailscaleActive: root.tailscaleActive,
      dockerContainers: root.dockerContainers.length,
      gameMountPresent: root.gameMountPresent
    });
  }

  // --- Configuration, naming and the first-run wizard ---
  function defaultServerName() {
    return Shell.trim(Quickshell.env("HOSTNAME") || "vemberos") || "vemberos";
  }

  function loadManifestInfo() {
    if (!manifestReadProc.running) manifestReadProc.running = true;
  }

  function loadHubConfig() {
    configReady = false;
    if (!configReadProc.running) configReadProc.running = true;
  }

  function openWizard(defaultName) {
    serverNameDraft = Shell.trim(defaultName || serverName || defaultServerName());
    serverRoleDraft = Shell.trim(serverRole || "");
    wizardOpen = true;
  }

  function normalizedTabOrder(order) {
    return Config.normalizedTabOrder(order);
  }

  function writeHubConfig(restartAfter) {
    pendingConfigRestart = !!restartAfter;
    if (pendingConfigRestart) restartingForServerName = true;
    else restartingForServerName = false;
    configWriteProc.running = false;
    var payload = JSON.stringify({
      serverName: serverName,
      serverRole: serverRole,
      preferredEditor: preferredEditor,
      tabOrder: normalizedTabOrder(tabOrder),
      codeServerPort: codeServerPort,
      wizardCompleted: true
    });
    configWriteProc.command = Config.writeCommand(root.configPath, payload);
    configWriteProc.running = true;
  }

  function saveServerName(name) {
    var n = Shell.trim(name);
    if (n.length === 0)
      n = defaultServerName();
    var r = Shell.trim(serverRoleDraft);
    serverName = n;
    serverNameDraft = n;
    serverRole = r;
    serverRoleDraft = r;
    wizardOpen = false;
    configReady = true;
    writeHubConfig(false);
  }

  function setPreferredEditor(editorId) {
    preferredEditor = Shell.trim(editorId);
    if (configReady || Shell.trim(serverName).length > 0)
      writeHubConfig(false);
  }

  function openRepoInEditor(repoPath) {
    var path = Shell.trim(repoPath);
    if (path.length === 0) return;
    var editor = Shell.trim(preferredEditor);
    if (editor.length === 0) {
      devStatus = "Select a preferred editor in Dev tab to open repositories.";
      lastActionMessage = devStatus;
      return;
    }
    var cmd = [
      "set -eu",
      "path=\"$1\"",
      "editor=\"$2\"",
      "bin=\"\"",
      "if [ \"$editor\" = zed ]; then",
      "  command -v zeditor >/dev/null 2>&1 && bin=zeditor || true",
      "  [ -z \"$bin\" ] && command -v zed >/dev/null 2>&1 && bin=zed || true",
      "elif [ \"$editor\" = vscode ]; then",
      "  command -v code >/dev/null 2>&1 && bin=code || true",
      "  [ -z \"$bin\" ] && command -v code-oss >/dev/null 2>&1 && bin=code-oss || true",
      "else",
      "  echo \"Unsupported editor: $editor\" >&2",
      "  exit 2",
      "fi",
      "if [ -z \"$bin\" ]; then",
      "  echo \"Editor not found in PATH for: $editor\" >&2",
      "  exit 127",
      "fi",
      "echo \"BIN=$bin\"",
      "nohup \"$bin\" \"$path\" >/dev/null 2>&1 &",
      "exit 0"
    ].join("\n");
    devOpenRepoProc.repoPath = path;
    devOpenRepoProc.editorId = editor;
    devOpenRepoProc.running = false;
    devOpenRepoProc.command = ["sh", "-c", cmd, "sh", path, editor];
    devOpenRepoProc.running = true;
    devStatus = "Opening " + path + " in " + DevTools.label(editor) + "…";
  }

  function selectDevRepo(repoPath) {
    var path = Shell.trim(repoPath);
    devSelectedRepoPath = path;
    devRepoDetail = ({});
    devRepoDetailBusy = false;
    devRepoDetailProc.running = false;
    if (path.length === 0) return;
    devRepoDetailBusy = true;
    devRepoDetailProc.repoPath = path;
    devRepoDetailProc.command = DevTools.repoDetailCommand(path);
    devRepoDetailProc.running = true;
  }

  // --- Refresh entry points ---
  function refreshAll() {
    lastActionMessage = "";
    refreshTailscale();
    refreshDocker();
    refreshGames();
    refreshGameMount();
    refreshSsh();
    refreshDev();
  }

  function refreshDev() {
    devError = "";
    devStatus = "Scanning development tools and repositories…";
    devBusy = true;
    devToolsOnlyRefresh = false;
    devTools = [];
    devRepos = [];
    devSelectedRepoPath = "";
    devRepoDetail = ({});
    devRepoDetailBusy = false;
    devRepoDetailProc.running = false;
    codeServerPresent = false;
    codeServerRunning = false;
    codeServerState = "unknown";
    codeServerStatusText = "";
    codeServerImage = "";
    devToolsProc.running = false;
    devToolsProc.running = true;
  }

  function refreshCodeServer() {
    codeServerProc.running = false;
    codeServerProc.running = true;
  }

  // --- Code Server (Docker) ---
  function _appendCodeServerSetupLog(line) {
    var t = String(line || "").replace(/\r/g, "");
    t = t.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
    if (Shell.trim(t).length === 0) return;
    var next = (root.codeServerSetupLog.length > 0 ? (root.codeServerSetupLog + "\n") : "") + t;
    if (next.length > 12000) next = next.slice(next.length - 12000);
    root.codeServerSetupLog = next;
  }

  function _updateCodeServerPullProgressFromLine(line) {
    var ev = Docker.parsePullLine(line);
    if (!ev) return;
    var layers = _codeServerPullLayers || {};
    if (ev.phase === "complete") {
      if (layers[ev.id] && isFinite(layers[ev.id].total))
        layers[ev.id].current = layers[ev.id].total;
      else
        return;
    } else if (isFinite(ev.current) && isFinite(ev.total) && ev.total > 0) {
      layers[ev.id] = { current: ev.current, total: ev.total };
    } else {
      return;
    }
    _codeServerPullLayers = layers;
    var agg = Docker.accumulateLayers(layers);
    if (agg.total <= 0) return;
    root.codeServerSetupBytesDone = agg.done;
    root.codeServerSetupBytesTotal = agg.total;
    root.codeServerSetupProgress = agg.progress;
    if (ev.phase !== "complete")
      root.codeServerSetupDetail = "Downloading image… " + Shell.humanBytes(agg.done) + " / " + Shell.humanBytes(agg.total);
  }

  function setupCodeServerTerminal(password, port) {
    var pass = Shell.trim(password);
    if (pass.length === 0) {
      codeServerStatusText = "Set a password for Code Server before setup.";
      lastActionMessage = "Code Server setup needs a password.";
      codeServerSetupStage = "error";
      codeServerSetupDetail = "Password required.";
      codeServerSetupProgress = 0;
      _appendCodeServerSetupLog("Error: password required.");
      return;
    }
    var p = Number(port);
    if (!isFinite(p) || Math.round(p) < 1 || Math.round(p) > 65535) p = Number(codeServerPort);
    if (!isFinite(p) || Math.round(p) < 1 || Math.round(p) > 65535) p = 8443;
    p = Math.round(p);
    codeServerPort = p;
    if (configReady || Shell.trim(serverName).length > 0) writeHubConfig(false);

    codeServerBusy = true;
    codeServerSetupStage = "preparing";
    codeServerSetupProgress = -1;
    codeServerSetupBytesDone = 0;
    codeServerSetupBytesTotal = 0;
    _codeServerPullLayers = ({});
    codeServerSetupLog = "";
    codeServerSetupDetail = "Preparing configuration and checking Docker…";
    codeServerStatusText = codeServerSetupDetail;
    codeServerSetupPollsLeft = 0;
    codeServerSetupPollTimer.stop();

    _appendCodeServerSetupLog("Starting setup for port " + p + "…");

    var csDir = DevTools.codeServerConfigDir();
    var csName = DevTools.codeServerContainer();
    var prep = [
      "set -e",
      "PASS=\"$VEMBER_CS_PASSWORD\"",
      "PORT=\"$1\"",
      "echo \"Password received (length: ${#PASS}).\"",
      "if [ -z \"$PASS\" ]; then echo 'Password is empty; aborting.'; exit 1; fi",
      "mkdir -p \"" + csDir + "/code-server\" \"" + csDir + "/user-data\" \"" + csDir + "/bin\" \"$HOME/Projects\"",
      "umask 077",
      "printf 'PASSWORD=%s\\n' \"$PASS\" > \"" + csDir + "/code-server.env\"",
      "{ echo 'bind-addr: 0.0.0.0:8080'; echo 'auth: password'; echo 'cert: false'; } > \"" + csDir + "/code-server/config.yaml\"",
      "umask 022",
      "if [ ! -f \"$HOME/Projects/vember-python.code-workspace\" ]; then cat > \"$HOME/Projects/vember-python.code-workspace\" <<'JSON'",
      "{",
      "  \"folders\": [",
      "    { \"path\": \".\" }",
      "  ],",
      "  \"settings\": {",
      "    \"python.defaultInterpreterPath\": \"python3\",",
      "    \"python.terminal.activateEnvironment\": true,",
      "    \"ruff.enable\": true,",
      "    \"editor.formatOnSave\": true,",
      "    \"[python]\": {",
      "      \"editor.defaultFormatter\": \"charliermarsh.ruff\",",
      "      \"editor.codeActionsOnSave\": {",
      "        \"source.fixAll.ruff\": \"explicit\",",
      "        \"source.organizeImports.ruff\": \"explicit\"",
      "      }",
      "    }",
      "  },",
      "  \"extensions\": {",
      "    \"recommendations\": [",
      "      \"ms-python.python\",",
      "      \"ms-python.debugpy\",",
      "      \"charliermarsh.ruff\"",
      "    ]",
      "  }",
      "}",
      "JSON",
      "  echo 'Created default Python workspace: ~/Projects/vember-python.code-workspace'",
      "else",
      "  echo 'Default Python workspace already exists: ~/Projects/vember-python.code-workspace'",
      "fi",
      "mkdir -p \"$HOME/Projects/.vscode\"",
      "if [ ! -f \"$HOME/Projects/.vscode/extensions.json\" ]; then cat > \"$HOME/Projects/.vscode/extensions.json\" <<'JSON'",
      "{",
      "  \"recommendations\": [",
      "    \"ms-python.python\",",
      "    \"ms-python.debugpy\",",
      "    \"charliermarsh.ruff\"",
      "  ]",
      "}",
      "JSON",
      "  echo 'Created workspace extension recommendations: ~/Projects/.vscode/extensions.json'",
      "else",
      "  echo 'Workspace extension recommendations already exist: ~/Projects/.vscode/extensions.json'",
      "fi",
      "if [ ! -f \"$HOME/Projects/.vscode/settings.json\" ]; then cat > \"$HOME/Projects/.vscode/settings.json\" <<'JSON'",
      "{",
      "  \"python.defaultInterpreterPath\": \"python3\",",
      "  \"python.terminal.activateEnvironment\": true,",
      "  \"ruff.enable\": true,",
      "  \"editor.formatOnSave\": true,",
      "  \"[python]\": {",
      "    \"editor.defaultFormatter\": \"charliermarsh.ruff\",",
      "    \"editor.codeActionsOnSave\": {",
      "      \"source.fixAll.ruff\": \"explicit\",",
      "      \"source.organizeImports.ruff\": \"explicit\"",
      "    }",
      "  }",
      "}",
      "JSON",
      "  echo 'Created workspace settings: ~/Projects/.vscode/settings.json'",
      "else",
      "  echo 'Workspace settings already exist: ~/Projects/.vscode/settings.json'",
      "fi",
      "mkdir -p \"" + csDir + "/user-data/User\"",
      "python3 - <<'PY'",
      "import json, os",
      "path = os.path.expanduser('~/.config/" + csName + "/user-data/User/settings.json')",
      "os.makedirs(os.path.dirname(path), exist_ok=True)",
      "data = {}",
      "if os.path.exists(path):",
      "    try:",
      "        with open(path) as f:",
      "            data = json.load(f)",
      "        if not isinstance(data, dict):",
      "            data = {}",
      "    except Exception:",
      "        data = {}",
      "data['terminal.integrated.cwd'] = '/home/coder/home/Projects'",
      "with open(path, 'w') as f:",
      "    json.dump(data, f, indent=4)",
      "    f.write('\\n')",
      "PY",
      "echo 'Set Code Server terminal default cwd to /home/coder/home/Projects'",
      "if docker ps -a --format '{{.Names}}' | grep -qx '" + csName + "'; then echo 'EXISTS'; exit 10; fi",
      "if ! command -v docker >/dev/null 2>&1; then echo 'Docker is not installed or not in PATH.'; exit 11; fi",
      "if ! docker info >/dev/null 2>&1; then echo 'Docker is not running or not accessible (try starting docker and ensuring access).'; exit 12; fi",
      "echo 'READY'"
    ].join("\n");
    codeServerSetupPrepProc.running = false;
    // Password goes through the environment: /proc/<pid>/cmdline is world-readable,
    // /proc/<pid>/environ is readable only by the owner.
    codeServerSetupPrepProc.environment = { VEMBER_CS_PASSWORD: pass };
    codeServerSetupPrepProc.command = ["sh", "-c", prep, "sh", String(p)];
    codeServerSetupPrepProc.running = true;
  }

  function startCodeServer() {
    if (codeServerBusy) return;
    codeServerBusy = true;
    codeServerActionProc.actionName = "start";
    codeServerActionProc.command = ["docker", "start", DevTools.codeServerContainer()];
    codeServerActionProc.running = true;
  }

  function stopCodeServer() {
    if (codeServerBusy) return;
    codeServerBusy = true;
    codeServerActionProc.actionName = "stop";
    codeServerActionProc.command = ["docker", "stop", DevTools.codeServerContainer()];
    codeServerActionProc.running = true;
  }

  function uninstallCodeServer() {
    if (codeServerBusy) return;
    codeServerBusy = true;
    codeServerSetupStage = "";
    codeServerSetupDetail = "";
    codeServerSetupProgress = -1;
    codeServerSetupPollsLeft = 0;
    codeServerSetupProvisionAfterStart = false;
    codeServerSetupPollTimer.stop();
    codeServerSetupProvisionProc.running = false;
    codeServerActionProc.actionName = "uninstall";
    codeServerActionProc.command = ["docker", "rm", "-f", DevTools.codeServerContainer()];
    codeServerActionProc.running = true;
  }

  function openCodeServer() {
    Qt.openUrlExternally("http://localhost:" + codeServerPort);
  }

  // --- Developer tools and repos ---
  function refreshDevTools() {
    devToolsProc.running = false;
    devToolsProc.running = true;
  }

  function runDevInstallSilent(toolId) {
    if (devInstallBusy || installRunning) return;
    var label = DevTools.label(toolId);
    var cmd = "";
    if (toolId === "uv") cmd = "curl -LsSf https://astral.sh/uv/install.sh | sh";
    else if (toolId === "python") cmd = "sudo -n pacman -S --needed --noconfirm python python-pip";
    else if (toolId === "gh") cmd = "sudo -n pacman -S --needed --noconfirm github-cli";
    else if (toolId === "zed") cmd = "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm zed-preview-bin || yay -S --needed --noconfirm zed; else sudo -n pacman -S --needed --noconfirm zed; fi";
    else if (toolId === "vscode") cmd = "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm visual-studio-code-bin; else sudo -n pacman -S --needed --noconfirm code; fi";
    else cmd = "echo 'No install command configured for " + String(toolId) + "'; exit 1";

    devInstallBusy = true;
    devInstallToolId = toolId;
    devInstallStatus = "Installing " + label + "…";
    devStatus = devInstallStatus;
    devInstallSilentProc.running = false;
    devInstallSilentProc.command = ["sh", "-c", cmd];
    devInstallSilentProc.running = true;
  }

  function openDevInstallTerminal(toolId) {
    var label = DevTools.label(toolId);
    var cmd = "";
    if (toolId === "uv") cmd = "curl -LsSf https://astral.sh/uv/install.sh | sh";
    else if (toolId === "python") cmd = "sudo pacman -S --needed --noconfirm python python-pip";
    else if (toolId === "gh") cmd = "sudo pacman -S --needed --noconfirm github-cli";
    else if (toolId === "zed") cmd = "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm zed-preview-bin || yay -S --needed --noconfirm zed; else sudo pacman -S --needed --noconfirm zed; fi";
    else if (toolId === "vscode") cmd = "if command -v yay >/dev/null 2>&1; then yay -S --needed --noconfirm visual-studio-code-bin; else sudo pacman -S --needed --noconfirm code; fi";
    else cmd = "echo 'No install command configured for " + String(toolId) + "'; exit 1";

    runInstallInTerminal("dev:" + toolId, "Vember Install: " + label, cmd, label);
  }

  // --- SSH keys ---
  function refreshSsh() {
    sshHostName = Quickshell.env("HOSTNAME") || "vemberos";
    if (!sshActiveProc.running) sshActiveProc.running = true;
    if (!sshEnabledProc.running) sshEnabledProc.running = true;
    if (!sshHostKeysProc.running) sshHostKeysProc.running = true;
    refreshAuthorizedKeys();
  }

  function refreshAuthorizedKeys() {
    if (!sshAuthorizedKeysProc.running) sshAuthorizedKeysProc.running = true;
  }

  function openAuthorizedKeysEditor() {
    sshAuthorizedKeysEditorProc.running = false;
    sshAuthorizedKeysEditorProc.command = ["omarchy-launch-editor", root.homeDir + "/.ssh/authorized_keys"];
    sshAuthorizedKeysEditorProc.running = true;
    sshAuthorizedKeysStatus = "Opened authorized_keys in editor.";
  }

  function addAuthorizedKey() {
    var key = Shell.trim(sshNewKeyText);
    if (key.length === 0) {
      sshAuthorizedKeysStatus = "Paste a public key to add.";
      return;
    }
    if (key.indexOf("\n") !== -1) {
      sshAuthorizedKeysStatus = "Add one public key at a time (single line).";
      return;
    }
    sshAuthorizedKeysAddProc.running = false;
    sshAuthorizedKeysAddProc.command = ["sh", "-c",
      "set -e; mkdir -p \"$HOME/.ssh\"; chmod 700 \"$HOME/.ssh\"; touch \"$HOME/.ssh/authorized_keys\"; chmod 600 \"$HOME/.ssh/authorized_keys\"; printf '%s\\n' \"$1\" >> \"$HOME/.ssh/authorized_keys\"",
      "sh", key];
    sshAuthorizedKeysAddProc.running = true;
    sshAuthorizedKeysStatus = "Adding key…";
  }

  function removeSelectedAuthorizedKey() {
    if (sshSelectedKeyIndex < 0 || sshSelectedKeyIndex >= sshAuthorizedKeys.length) {
      sshAuthorizedKeysStatus = "Select a key to remove.";
      return;
    }
    var entry = sshAuthorizedKeys[sshSelectedKeyIndex];
    var lineNo = Number(entry.lineNo || 0);
    if (!(lineNo > 0)) {
      sshAuthorizedKeysStatus = "Could not determine key line to remove.";
      return;
    }
    sshAuthorizedKeysRemoveProc.targetLineNo = lineNo;
    sshAuthorizedKeysRemoveProc.running = false;
    sshAuthorizedKeysRemoveProc.command = ["sh", "-c",
      "set -e; file=\"$HOME/.ssh/authorized_keys\"; [ -f \"$file\" ] || exit 0; tmp=$(mktemp \"$HOME/.ssh/.authorized_keys.XXXXXX\"); awk -v n=\"$1\" 'NR!=n {print}' \"$file\" > \"$tmp\" && mv \"$tmp\" \"$file\"; chmod 600 \"$file\"",
      "sh", String(lineNo)];
    sshAuthorizedKeysRemoveProc.running = true;
    sshAuthorizedKeysStatus = "Removing key…";
  }

  function generateSshIdentityKey() {
    if (sshGenerateBusy)
      return;
    sshGenerateBusy = true;
    sshGeneratedPublicKey = "";
    sshAuthorizedKeysStatus = "Generating SSH identity keypair (~/.ssh/id_ed25519)…";
    sshGenerateKeyProc.running = false;
    sshGenerateKeyProc.command = ["sh", "-c",
      "set -e; key=\"$HOME/.ssh/id_ed25519\"; if [ -f \"$key\" ] || [ -f \"$key.pub\" ]; then echo 'Key already exists at ~/.ssh/id_ed25519 (or .pub). Not overwriting.' >&2; exit 2; fi; mkdir -p \"$HOME/.ssh\"; chmod 700 \"$HOME/.ssh\"; comment=\"${USER:-elena}@${HOSTNAME:-vemberos}\"; ssh-keygen -t ed25519 -f \"$key\" -N '' -C \"$comment\" >/dev/null 2>&1; chmod 600 \"$key\"; chmod 644 \"$key.pub\"; cat \"$key.pub\""];
    sshGenerateKeyProc.running = true;
  }

  // --- Tailscale and Docker status ---
  function refreshTailscale() {
    tailscaleNote = "";
    if (!tsActiveProc.running) tsActiveProc.running = true;
    if (!tsEnabledProc.running) tsEnabledProc.running = true;
    if (!tsIpProc.running) tsIpProc.running = true;
    if (!tsStatusProc.running) tsStatusProc.running = true;
    if (!tsStatusJsonProc.running) tsStatusJsonProc.running = true;
  }

  function refreshDocker() {
    dockerError = "";
    if (!dockerPsProc.running) dockerPsProc.running = true;
  }

  function refreshDockerDetailSize(name) {
    var target = Shell.trim(name);
    dockerDetailSizeName = target;
    dockerDetailSizeText = "";
    dockerDetailSizeError = "";
    dockerSizeProc.running = false;
    if (target.length === 0) {
      dockerDetailSizeBusy = false;
      return;
    }
    dockerDetailSizeBusy = true;
    dockerSizeProc.containerName = target;
    dockerSizeProc.command = ["docker", "ps", "-a", "-s", "--no-trunc", "--filter", "name=^/" + target + "$", "--format", "{{.Size}}"];
    dockerSizeProc.running = true;
  }

  function refreshGameMount() {
    gameMountError = "";
    if (!findmntProc.running) findmntProc.running = true;
    if (!dfProc.running) dfProc.running = true;
  }

  function refreshGames() {
    steamNote = "";
    bnetNote = "";
    var steamRoot = Gaming.steamRootPath(homeDir);
    steamInstalled = false;
    bnetInstalled = false;
    steamRunning = false;
    bnetRunning = false;
    steamGameCount = -1;
    steamDedicatedServers = [];
    bnetGameCount = -1;
    if (!steamPgrepProc.running) steamPgrepProc.running = true;
    if (!bnetPgrepProc.running) bnetPgrepProc.running = true;
    steamDirProc.command = ["sh", "-c", "[ -d \"$1\" ] || command -v steam >/dev/null 2>&1", "sh", steamRoot];
    if (!steamDirProc.running) steamDirProc.running = true;
    bnetDirProc.command = ["test", "-d", Gaming.battlenetPrefixPath(homeDir)];
    if (!bnetDirProc.running) bnetDirProc.running = true;
    // Baseline count: default + common external library; vdf load will refine to all libraries.
    var baselineDirs = [steamRoot + "/steamapps", "/mnt/games/SteamLibrary/steamapps"];
    steamManifestProc.running = false;
    steamManifestProc.command = Gaming.steamManifestCountCommandForDirs(baselineDirs);
    steamManifestProc.running = true;
    steamVdfView.path = "";
    steamVdfView.path = Gaming.steamLibraryVdfPath(homeDir);
    bnetGameCountProc.command = Gaming.battlenetGameCountCommand(homeDir);
    if (!bnetGameCountProc.running) bnetGameCountProc.running = true;

    extraAppsScanBusy = true;
    extraAppsScanProc.running = false;
    extraAppsScanProc.command = Gaming.scanCommand();
    extraAppsScanProc.running = true;
  }

  function launchExtraApp(appId) {
    var def = Gaming.defById(appId);
    if (!def) {
      lastActionMessage = "Unknown app: " + appId;
      return;
    }
    extraAppLaunchProc.appId = appId;
    extraAppLaunchProc.appName = def.name || appId;
    extraAppLaunchProc.running = false;
    extraAppLaunchProc.command = def.launchCmd;
    extraAppLaunchProc.running = true;
    lastActionMessage = "Launching " + (def.name || appId) + "…";
  }

  function installExtraApp(appId) {
    var def = Gaming.defById(appId);
    if (!def) {
      lastActionMessage = "Unknown app: " + appId;
      return;
    }
    var name = def.name || appId;
    runInstallInTerminal(appId, "Vember Install: " + name, String(def.installCmd || ""), name);
  }

  function installSteam() {
    runInstallInTerminal("steam", "Vember Install: Steam", Gaming.steamInstallCommand(), "Steam");
  }

  function openBattlenetSetup() {
    extraAppInstallStatus = "Battle.net installs through Lutris or a Wine prefix. Opening the Lutris Battle.net page…";
    lastActionMessage = extraAppInstallStatus;
    Qt.openUrlExternally(Gaming.battlenetSetupUrl());
  }

  // --- Terminal installs: log, lock and reattach ---
  function runInstallInTerminal(id, title, cmd, label) {
    if (installRunning) {
      lastActionMessage = "An install is already running: " + (installTitle.length > 0 ? installTitle : installRunningId);
      return;
    }
    var command = Shell.trim(cmd);
    if (command.length === 0)
      command = "echo 'No install command configured.'; exit 1";
    var logPath = InstallLog.logPath(homeDir);
    var titlePath = InstallLog.titlePath(homeDir);
    installRunning = true;
    installRunningId = String(id || "");
    installTitle = String(title || "Install");
    installLog = "";
    extraAppInstallStatus = "Installing " + (label || installTitle) + " in the default terminal — answer any prompts there. Live output below.";
    lastActionMessage = extraAppInstallStatus;
    if (installIsDev) {
      devInstallBusy = true;
      devInstallToolId = installRunningId.slice(4);
      devInstallStatus = extraAppInstallStatus;
      devStatus = devInstallStatus;
    }
    installTerminalProc.running = false;
    installTerminalProc.command = ["sh", "-c",
      InstallLog.terminalScript(installTitle, command, logPath, titlePath,
        InstallLog.lockPath(homeDir), installRunningId)];
    installTerminalProc.running = true;
    installLogProc.running = false;
    installLogProc.command = ["tail", "-n", "+1", "-F", logPath];
    installLogProc.running = true;
    installNoOutputTimer.restart();
    installStallTimer.restart();
  }

  function finishInstall(code) {
    installLogProc.running = false;
    installNoOutputTimer.stop();
    installStallTimer.stop();
    installRunning = false;
    var label = Shell.trim(installTitle).length > 0 ? installTitle.replace(/^Vember Install:\s*/, "") : "Install";
    if (code === 0)
      extraAppInstallStatus = label + " finished.";
    else if (code === null || isNaN(code))
      extraAppInstallStatus = label + " finished (exit code unknown).";
    else
      extraAppInstallStatus = label + " failed (exit code " + code + ").";
    if (installIsDev) {
      devInstallBusy = false;
      devInstallToolId = "";
      devInstallStatus = extraAppInstallStatus;
      devStatus = devInstallStatus;
    }
    lastActionMessage = extraAppInstallStatus;
    installRefreshTimer.restart();
    installRefreshTimer2.restart();
  }

  function stopInstall() {
    installLogProc.running = false;
    installNoOutputTimer.stop();
    installStallTimer.stop();
    installRunning = false;
    if (installIsDev) {
      devInstallBusy = false;
      devInstallToolId = "";
      devInstallStatus = "Install tracking stopped (the terminal may still be running).";
      devStatus = devInstallStatus;
    }
    extraAppInstallStatus = "Install tracking stopped (the terminal may still be running).";
    lastActionMessage = extraAppInstallStatus;
  }

  function clearInstallLog() {
    if (installRunning)
      return;
    installLog = "";
    installTitle = "";
    extraAppInstallStatus = "";
    installClearProc.running = false;
    installClearProc.command = ["sh", "-c",
      "rm -f \"$1\" \"$2\" \"$3\"", "sh",
      InstallLog.titlePath(homeDir), InstallLog.logPath(homeDir),
      InstallLog.lockPath(homeDir)];
    installClearProc.running = true;
  }

  function refreshAfterInstall() {
    refreshGames();
    if (installIsDev)
      refreshDevTools();
  }

  function loadInstallLog() {
    if (installRunning)
      return;
    installLogReadProc.running = false;
    installLogReadProc.command = ["sh", "-c",
      "t=\"$1\"; l=\"$2\"; k=\"$3\"; " +
      "[ -f \"$t\" ] && cat \"$t\" || true; " +
      "printf '\\n---VEMBER-STATE---\\n'; " +
      "if [ -f \"$k\" ]; then " +
      "id=$(sed -n 1p \"$k\"); pid=$(sed -n 2p \"$k\"); " +
      "if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null; then printf 'ALIVE\\n%s\\n' \"$id\"; else printf 'DEAD\\n%s\\n' \"$id\"; fi; " +
      "else printf 'NONE\\n\\n'; fi; " +
      "printf -- '---VEMBER-LOG---\\n'; " +
      "[ -f \"$l\" ] && tail -c 12000 \"$l\" || true",
      "sh", InstallLog.titlePath(homeDir), InstallLog.logPath(homeDir),
      InstallLog.lockPath(homeDir)];
    installLogReadProc.running = true;
  }

  // --- Tailscale actions ---
  function runTailscaleAction(action) {
    if (tailscaleBusy)
      return;
    tailscaleBusy = true;
    tailscaleNote = "Running pkexec systemctl " + action + " tailscaled…";
    tsActionProc.actionName = action;
    tsActionProc.command = Systemd.pkexecCommand(action, "tailscaled");
    tsActionProc.running = true;
  }

  function runTailscaleActionInTerminal(action) {
    tsTerminalProc.command = Systemd.terminalCommand(action, "tailscaled");
    tsTerminalProc.running = true;
    tailscaleNote = "Opened terminal for: sudo systemctl " + action + " tailscaled";
  }

  // --- Omarchy system update ---
  function runOmarchyUpdateInPanel() {
    if (omarchyUpdateRunning)
      return;
    var logPath = homeDir + "/.cache/vember-server-hub/omarchy-update.log";
    var lockPath = InstallLog.omarchyLockPath(homeDir);
    var termCmd = "printf '%s\\n' \"$$\" > " + Shell.quote(lockPath) +
      "; ( /usr/share/omarchy/bin/omarchy-update ) 2>&1 | tee " + Shell.quote(logPath) +
      "; code=${PIPESTATUS[0]}; if [ -z \"$code\" ]; then code=1; fi" +
      "; echo \"[vember-update-exit:${code}]\" | tee -a " + Shell.quote(logPath) +
      "; rm -f " + Shell.quote(lockPath) +
      "; echo; echo 'Press Enter to close...'; read -r";
    omarchyUpdateLog = "";
    omarchyUpdateStatus = "Running Omarchy update in default terminal (interactive)… streaming live log below.";
    lastActionMessage = "Running Omarchy update in default terminal.";
    omarchyUpdateRunning = true;
    omarchyUpdateLogProc.running = false;
    omarchyUpdateTerminalProc.running = false;
    omarchyUpdateTerminalProc.command = ["sh", "-c",
      "mkdir -p " + Shell.quote(homeDir + "/.cache/vember-server-hub") +
      " && : > " + Shell.quote(logPath) +
      " && xdg-terminal-exec --title=" + Shell.quote("Vember Omarchy Update") +
      " bash -lc " + Shell.quote(termCmd) + " </dev/null >/dev/null 2>&1 & " +
      "sleep 0.5; hyprctl dispatch focuswindow 'title:^(Vember Omarchy Update)$' >/dev/null 2>&1 || hyprctl dispatch focuswindow 'title:Vember Omarchy Update' >/dev/null 2>&1 || true"];
    omarchyUpdateTerminalProc.running = true;
    omarchyUpdateLogProc.command = ["tail", "-n", "+1", "-F", logPath];
    omarchyUpdateLogProc.running = true;
    omarchyUpdateStallTimer.restart();
  }

  function stopOmarchyUpdateLog() {
    omarchyUpdateLogProc.running = false;
    omarchyUpdateStallTimer.stop();
    omarchyUpdateRunning = false;
    omarchyUpdateStatus = "Live log stopped.";
  }

  function clearOmarchyUpdateLog() {
    omarchyUpdateLog = "";
    if (!omarchyUpdateRunning)
      omarchyUpdateStatus = "";
  }

  function loadOmarchyUpdateLog() {
    if (omarchyUpdateRunning)
      return;
    omarchyUpdateLogReadProc.running = false;
    omarchyUpdateLogReadProc.command = ["sh", "-c",
      "f=\"$1\"; k=\"$2\"; " +
      "if [ -f \"$k\" ]; then pid=$(sed -n 1p \"$k\"); " +
      "if [ -n \"$pid\" ] && kill -0 \"$pid\" 2>/dev/null; then printf 'ALIVE\\n'; else printf 'DEAD\\n'; fi; " +
      "else printf 'NONE\\n'; fi; " +
      "printf -- '---VEMBER-UPDATE-LOG---\\n'; " +
      "[ -f \"$f\" ] && tail -c 14000 \"$f\" 2>/dev/null || true",
      "sh", homeDir + "/.cache/vember-server-hub/omarchy-update.log",
      InstallLog.omarchyLockPath(homeDir)];
    omarchyUpdateLogReadProc.running = true;
  }

  // --- Plugin self-update (GitHub) ---
  property var _pluginUpdatePuns: [
    "Fetching commits… this won’t take a commit-ment.",
    "Pulling changes… brace for deploy-lightful results.",
    "Syncing with GitHub… git ready.",
    "Merging progress… no need to branch out.",
    "Applying updates… pushing my luck (safely).",
    "Fast-forwarding… keeping things up to date-stamp.",
    "Downloading improvements… serving fresh bits.",
    "Almost there… hubba hubba, here comes the hub."
  ]
  property int _pluginUpdatePunIndex: 0

  function _nextPluginUpdatePun() {
    var puns = _pluginUpdatePuns || [];
    if (puns.length === 0) return "";
    _pluginUpdatePunIndex = (_pluginUpdatePunIndex + 1) % puns.length;
    return puns[_pluginUpdatePunIndex];
  }

  function _resolvedPluginRepoDir() {
    var d = Shell.trim(pluginRepoDir);
    if (d.length > 0) return d;
    return homeDir + "/Projects/vember-server";
  }

  function checkPluginUpdate(manual) {
    if (updateCheckBusy || pluginUpdateBusy)
      return;
    pluginUpdateError = "";
    if (pluginUpdateProgress >= 1) pluginUpdateProgress = 0;
    if (manual) {
      pluginUpdateStatus = "Checking for updates…";
      pluginUpdatePun = "";
    }
    updateCheckBusy = true;
    pluginRepoResolveProc.running = false;
    pluginRepoResolveProc.command = ["sh", "-c", "d=\"$1\"; git -C \"$d\" rev-parse --show-toplevel 2>/dev/null || echo \"$HOME/Projects/vember-server\"", "sh", homeDir + "/.config/omarchy/plugins/elena.vember-server-hub"];
    pluginRepoResolveProc.running = true;
  }

  function startPluginUpdate() {
    if (pluginUpdateBusy)
      return;
    pluginUpdateBusy = true;
    pluginUpdateError = "";
    pluginUpdateProgress = 0.05;
    _pluginUpdatePunIndex = Math.floor(Math.random() * (_pluginUpdatePuns.length || 1));
    pluginUpdatePun = (_pluginUpdatePuns[_pluginUpdatePunIndex] || "Updating…");
    pluginUpdateStatus = "Starting update…";
    pluginUpdatePunTimer.restart();
    pluginUpdateFetchProc.running = false;
    pluginUpdateFetchProc.command = ["sh", "-c", "cd \"$1\" && git fetch origin 2>&1", "sh", _resolvedPluginRepoDir()];
    pluginUpdateFetchProc.running = true;
  }

  // --- Docker actions ---
  function runDockerAction(action, name) {
    if (dockerBusy)
      return;
    dockerBusy = true;
    dockerBusyName = name;
    dockerActionProc.actionName = action;
    dockerActionProc.containerName = name;
    dockerActionProc.command = Docker.actionCommand(action, name);
    dockerActionProc.running = true;
  }

  function runDockerPull(image, name) {
    if (dockerBusy)
      return;
    if (Shell.trim(image).length === 0) {
      dockerPullResult = "Cannot pull image for " + name + ": image name unknown.";
      dockerPullingName = name;
      dockerPullActive = false;
      return;
    }
    dockerBusy = true;
    dockerBusyName = name;
    dockerPullActive = true;
    dockerPullingName = name;
    dockerPullingImage = image;
    dockerPullStatus = "Pulling " + image + "…";
    dockerPullPercent = -1;
    dockerPullResult = "";
    dockerPullProc.actionName = "pull";
    dockerPullProc.containerName = name;
    dockerPullProc.imageName = image;
    dockerPullProc.command = Docker.pullCommand(image);
    dockerPullProc.running = true;
  }

  // --- Processes: Tailscale ---
  Process {
    id: tsActiveProc
    command: Systemd.isActiveCommand("tailscaled")
    stdout: StdioCollector { onStreamFinished: root.tailscaleActive = Shell.trim(text) || "unknown" }
  }
  Process {
    id: tsEnabledProc
    command: Systemd.isEnabledCommand("tailscaled")
    stdout: StdioCollector { onStreamFinished: root.tailscaleEnabled = Shell.trim(text) || "unknown" }
  }
  Process {
    id: tsIpProc
    command: Tailscale.ipCommand()
    stdout: StdioCollector { onStreamFinished: root.tailscaleIp = Shell.nonEmptyLines(text).join(", ") }
  }
  Process {
    id: tsStatusProc
    command: Tailscale.statusCommand()
    stdout: StdioCollector { onStreamFinished: root.tailscaleStatusText = Shell.trim(text) }
  }
  Process {
    id: tsStatusJsonProc
    command: Tailscale.statusJsonCommand()
    stdout: StdioCollector {
      onStreamFinished: {
        var info = Tailscale.parseStatusJson(text);
        if (info.ok) {
          root.tailscaleTailnetName = info.tailnetName || "";
          root.tailscaleSelf = info.self;
          root.tailscalePeers = info.peers || [];
          if (info.backendState && root.tailscaleActive === "unknown")
            root.tailscaleActive = "active";
        } else {
          // keep previous structured data if parse fails
        }
      }
    }
  }
  Process {
    id: tsActionProc
    property string actionName: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.tailscaleBusy = false;
      if (code === 0) {
        root.tailscaleNote = "tailscaled " + actionName + " succeeded.";
      } else {
        // pkexec refusals and polkit denials read the same as "code 1"
        // otherwise, so fold in what the tool actually said.
        root.tailscaleNote = Shell.failureMessage(
          "pkexec/systemctl " + actionName + " failed", code, tsActionProc.stderr.text) +
          " Try 'Run in terminal (sudo)'.";
      }
      root.refreshTailscale();
    }
  }
  Process {
    id: tsTerminalProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // --- Processes: SSH ---
  Process {
    id: sshActiveProc
    command: Systemd.isActiveCommand("sshd")
    stdout: StdioCollector { onStreamFinished: root.sshActive = Shell.trim(text) || "unknown" }
  }
  Process {
    id: sshEnabledProc
    command: Systemd.isEnabledCommand("sshd")
    stdout: StdioCollector { onStreamFinished: root.sshEnabled = Shell.trim(text) || "unknown" }
  }
  Process {
    id: sshHostKeysProc
    command: Ssh.hostKeyFingerprintsCommand()
    stdout: StdioCollector {
      onStreamFinished: root.sshHostKeys = Ssh.parseHostKeyFingerprints(text)
    }
  }
  Process {
    id: sshAuthorizedKeysProc
    command: Ssh.authorizedKeysReadCommand(root.homeDir)
    stdout: StdioCollector {
      onStreamFinished: {
        root.sshAuthorizedKeys = Ssh.parseAuthorizedKeys(text);
        if (root.sshSelectedKeyIndex >= root.sshAuthorizedKeys.length)
          root.sshSelectedKeyIndex = root.sshAuthorizedKeys.length > 0 ? 0 : -1;
      }
    }
  }
  Process {
    id: sshAuthorizedKeysEditorProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: sshAuthorizedKeysAddProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) {
        root.sshNewKeyText = "";
        root.sshAuthorizedKeysStatus = "Key added.";
        root.refreshAuthorizedKeys();
      } else {
        var err = Shell.trim(sshAuthorizedKeysAddProc.stderr.text || "");
        root.sshAuthorizedKeysStatus = "Failed to add key (code " + code + ")" + (err.length > 0 ? (": " + err) : ".");
      }
    }
  }
  Process {
    id: sshAuthorizedKeysRemoveProc
    property int targetLineNo: 0
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) {
        root.sshAuthorizedKeysStatus = "Key removed.";
        root.sshSelectedKeyIndex = -1;
        root.refreshAuthorizedKeys();
      } else {
        var err = Shell.trim(sshAuthorizedKeysRemoveProc.stderr.text || "");
        root.sshAuthorizedKeysStatus = "Failed to remove key (code " + code + ")" + (err.length > 0 ? (": " + err) : ".");
      }
    }
  }
  Process {
    id: sshGenerateKeyProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.sshGenerateBusy = false;
      var out = Shell.trim(sshGenerateKeyProc.stdout.text || "");
      var err = Shell.trim(sshGenerateKeyProc.stderr.text || "");
      if (code === 0) {
        root.sshGeneratedPublicKey = out;
        root.sshAuthorizedKeysStatus = "Generated identity keypair: ~/.ssh/id_ed25519 (public key shown below).";
      } else {
        root.sshGeneratedPublicKey = "";
        root.sshAuthorizedKeysStatus = "Failed to generate key (code " + code + ")" + (err.length > 0 ? (": " + err) : (out.length > 0 ? (": " + out) : "."));
      }
    }
  }

  // --- Processes: Omarchy update ---
  Process {
    id: omarchyUpdateTerminalProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Process {
    id: omarchyUpdateLogProc
    function appendLog(line) {
      var raw = String(line || "").replace(/\r/g, "");
      var t = raw;
      t = t.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
      t = t.replace(/\x1B\][^\x07]*(\x07|\x1B\\)/g, "");
      t = t.replace(/\x1B\[\?[0-9;]*[a-zA-Z]/g, "");
      var marker = t.match(/\[vember-update-exit:(-?\d*)\]/);
      if (marker) {
        var codeStr = marker[1];
        var code = (codeStr === "" ? NaN : Number(codeStr));
        root.omarchyUpdateRunning = false;
        if (code === 0)
          root.omarchyUpdateStatus = "Omarchy update finished.";
        else if (isNaN(code))
          root.omarchyUpdateStatus = "Omarchy update finished (exit code unknown).";
        else
          root.omarchyUpdateStatus = "Omarchy update exited (code " + code + ").";
        omarchyUpdateLogProc.running = false;
        omarchyUpdateStallTimer.stop();
        // don't append the internal marker line to visible log
        return;
      }
      if (Shell.trim(t).length === 0)
        return;
      var next = (root.omarchyUpdateLog.length > 0 ? (root.omarchyUpdateLog + "\n") : "") + t;
      if (next.length > 14000)
        next = next.slice(next.length - 14000);
      root.omarchyUpdateLog = next;
    }
    stdout: SplitParser { onRead: function(line) { omarchyUpdateLogProc.appendLog(line) } }
    stderr: SplitParser { onRead: function(line) { omarchyUpdateLogProc.appendLog(line) } }
    onExited: function(code) {
      // tail process exited (stopped by user or after marker handling)
      if (root.omarchyUpdateRunning) {
        root.omarchyUpdateRunning = false;
        omarchyUpdateStallTimer.stop();
        if (Shell.trim(root.omarchyUpdateStatus).indexOf("Running") === 0)
          root.omarchyUpdateStatus = "Live log stopped.";
      }
    }
  }

  Process {
    id: omarchyUpdateLogReadProc
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.omarchyUpdateRunning)
          return;
        var raw = String(text || "").replace(/\r/g, "");
        var logMark = "---VEMBER-UPDATE-LOG---";
        var markIdx = raw.indexOf(logMark);
        var lockState = Shell.trim(markIdx >= 0 ? raw.slice(0, markIdx) : "");
        var body = markIdx >= 0 ? raw.slice(markIdx + logMark.length) : raw;
        // strip ANSI codes
        var t = body.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
        t = t.replace(/\x1B\][^\x07]*(\x07|\x1B\\)/g, "");
        t = t.replace(/\x1B\[\?[0-9;]*[a-zA-Z]/g, "");
        // remove internal exit marker lines
        var lines = t.split("\n");
        var out = [];
        var lastMarkerCode = null;
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i];
          var m = line.match(/\[vember-update-exit:(-?\d*)\]/);
          if (m) {
            lastMarkerCode = m[1];
            continue;
          }
          out.push(line);
        }
        // trim trailing empty lines
        while (out.length > 0 && Shell.trim(out[out.length - 1]).length === 0) out.pop();
        var joined = out.join("\n");
        if (joined.length > 14000) joined = joined.slice(joined.length - 14000);
        root.omarchyUpdateLog = joined;
        if (lockState === "ALIVE") {
          // The update terminal outlived the panel: resume live streaming
          root.omarchyUpdateRunning = true;
          root.omarchyUpdateStatus = "Reattached to the running Omarchy update. Live log below.";
          root.lastActionMessage = root.omarchyUpdateStatus;
          omarchyUpdateLogProc.command = ["tail", "-n", "+1", "-F",
            root.homeDir + "/.cache/vember-server-hub/omarchy-update.log"];
          omarchyUpdateLogProc.running = true;
          omarchyUpdateStallTimer.restart();
          return;
        }
        if (Shell.trim(root.omarchyUpdateStatus).length === 0 && joined.length > 0) {
          if (lastMarkerCode !== null) {
            if (lastMarkerCode === "" ) root.omarchyUpdateStatus = "Omarchy update finished (exit code unknown).";
            else if (Number(lastMarkerCode) === 0) root.omarchyUpdateStatus = "Omarchy update finished.";
            else root.omarchyUpdateStatus = "Omarchy update exited (code " + lastMarkerCode + ").";
          } else {
            root.omarchyUpdateStatus = "Previous update log loaded.";
          }
        }
      }
    }
    stderr: StdioCollector {}
  }

  // Watchdog for the Omarchy update. Same failure mode as an install: if the
  // terminal is closed mid-update there is no exit marker and `tail -F` never
  // ends, so the panel would sit on "running" forever. The update lock stores
  // only the pid, on line 1, so that is the pid line passed here.
  Timer {
    id: omarchyUpdateStallTimer
    interval: 30000
    repeat: true
    onTriggered: {
      if (!root.omarchyUpdateRunning)
        return;
      omarchyUpdateLockCheckProc.command =
        InstallLog.lockCheckCommand(InstallLog.omarchyLockPath(root.homeDir), 1);
      omarchyUpdateLockCheckProc.running = true;
    }
  }

  Process {
    id: omarchyUpdateLockCheckProc
    onExited: function(code) {
      if (!root.omarchyUpdateRunning)
        return;
      var hasOutput = Shell.trim(root.omarchyUpdateLog).length > 0;
      var verdict = InstallLog.watchdogVerdict(code, hasOutput);
      if (verdict === "never-started") {
        root.stopOmarchyUpdateLog();
        root.omarchyUpdateStatus = "Could not open the update terminal. Check that xdg-terminal-exec works.";
        root.lastActionMessage = root.omarchyUpdateStatus;
      } else if (verdict === "dead") {
        root.stopOmarchyUpdateLog();
        root.omarchyUpdateStatus = "The update terminal closed before finishing. Tracking stopped.";
        root.lastActionMessage = root.omarchyUpdateStatus;
      }
      // alive / wait / teardown: keep tracking; `tail` or the next tick resolves it.
    }
  }

  // --- Processes: Launchers ---
  Process {
    id: steamLaunchProc
    command: ["steam"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: bnetLaunchProc
    command: ["omarchy-launch-battlenet"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: hotReloadProc
    command: ["sh", "-c", "setsid sh -c 'sleep 0.6; omarchy restart shell; sleep 2.5; omarchy-shell shell toggle elena.vember-server-hub \"{}\"' >/dev/null 2>&1 &"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  // --- Launchers ---
  function launchSteam() {
    steamLaunchProc.running = false;
    steamLaunchProc.running = true;
    lastActionMessage = "Launching Steam…";
  }

  function launchBattleNet() {
    bnetLaunchProc.running = false;
    bnetLaunchProc.running = true;
    lastActionMessage = "Launching Battle.net…";
  }

  // --- Hot reload ---
  function hotReloadHub() {
    lastActionMessage = "Hot reloading: restarting shell and reopening hub…";
    hotReloadProc.running = false;
    hotReloadProc.running = true;
  }

  // --- Processes: Docker ---
  Process {
    id: dockerPsProc
    command: Docker.psCommand()
    stdout: StdioCollector {
      onStreamFinished: root.dockerContainers = Docker.parsePs(text)
    }
    stderr: StdioCollector {
      onStreamFinished: if (Shell.trim(text).length > 0) root.dockerError = Shell.trim(text)
    }
    onExited: function(code) {
      if (code !== 0 && root.dockerContainers.length === 0 && root.dockerError.length === 0)
        root.dockerError = "docker ps failed (code " + code + "). Is Docker available?"
    }
  }
  Process {
    id: dockerActionProc
    property string actionName: ""
    property string containerName: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.dockerBusy = false;
      var target = containerName;
      root.dockerBusyName = "";
      if (code === 0) {
        root.lastActionMessage = "Docker " + actionName + " succeeded: " + target;
      } else {
        // Include the daemon's own reason: "code 1" alone is not actionable.
        root.lastActionMessage = Shell.failureMessage(
          "Docker " + actionName + " failed for " + target, code, dockerActionProc.stderr.text);
      }
      root.refreshDocker();
    }
  }

  Process {
    id: dockerPullProc
    property string actionName: "pull"
    property string containerName: ""
    property string imageName: ""
    property string lastLine: ""
    function handleLine(line) {
      var t = Shell.trim(line);
      if (t.length === 0)
        return;
      lastLine = t;
      root.dockerPullStatus = t;
      var m = /(\d{1,3})%/.exec(t);
      if (m) {
        var p = Number(m[1]);
        if (isFinite(p))
          root.dockerPullPercent = Math.max(0, Math.min(100, p)) / 100.0;
      }
    }
    stdout: SplitParser { onRead: function(line) { dockerPullProc.handleLine(line) } }
    stderr: SplitParser { onRead: function(line) { dockerPullProc.handleLine(line) } }
    onExited: function(code) {
      root.dockerBusy = false;
      root.dockerBusyName = "";
      root.dockerPullActive = false;
      var image = imageName;
      if (code === 0) {
        root.dockerPullStatus = "Pull complete";
        root.dockerPullPercent = 1;
        root.dockerPullResult = "Updated image: " + image;
      } else {
        // Surface the daemon's own last line: "code 1" alone does not say
        // whether it was a bad tag, no space left, or a network stall.
        var reason = Shell.trim(lastLine);
        root.dockerPullStatus = "Pull failed (code " + code + ")";
        root.dockerPullResult = "Pull failed for " + image +
          (reason.length > 0 ? (": " + reason) : (" (code " + code + ")")) + ".";
      }
      root.refreshDocker();
    }
  }

  Process {
    id: dockerPruneProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.dockerPruneBusy = false;
      var out = Shell.trim(dockerPruneProc.stdout.text || "");
      var err = Shell.trim(dockerPruneProc.stderr.text || "");
      if (code === 0) {
        if (out.length > 0) {
          var lines = out.split("\n").map(function(l){ return Shell.trim(l); }).filter(function(l){ return l.length > 0; });
          root.lastActionMessage = "Pruned stopped containers. " + lines.join(" • ");
        } else {
          root.lastActionMessage = "Pruned stopped containers.";
        }
      } else {
        root.lastActionMessage = "Docker prune failed (code " + code + ")" + (err.length > 0 ? (": " + err) : ".");
      }
      root.refreshDocker();
    }
  }

  Process {
    id: dockerSizeProc
    property string containerName: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (containerName !== root.dockerDetailSizeName)
        return;
      root.dockerDetailSizeBusy = false;
      if (code === 0) {
        var out = Shell.trim(stdout.text || "");
        var line = "";
        var parts = out.split(/\r?\n/);
        for (var i = 0; i < parts.length; i++) {
          var t = Shell.trim(parts[i]);
          if (t.length > 0) { line = t; break; }
        }
        root.dockerDetailSizeText = line.length > 0 ? line : "Unknown";
        root.dockerDetailSizeError = "";
      } else {
        var err = Shell.trim(stderr.text || "");
        root.dockerDetailSizeText = "";
        root.dockerDetailSizeError = err.length > 0 ? err : ("Failed to query size (code " + code + ").");
      }
    }
  }

  function pruneStoppedContainers() {
    if (dockerPruneBusy || dockerBusy)
      return;
    dockerPruneBusy = true;
    dockerPruneProc.command = Docker.pruneCommand();
    dockerPruneProc.running = true;
    lastActionMessage = "Pruning stopped containers…";
  }

  // --- Processes / views: Games ---
  Process {
    id: steamPgrepProc
    command: SystemInfo.pgrepExactCommand("steam")
    onExited: function(code) { root.steamRunning = (code === 0) }
  }
  Process {
    id: bnetPgrepProc
    command: ["pgrep", "-f", "Battle.net"]
    onExited: function(code) { root.bnetRunning = (code === 0) }
  }
  Process {
    id: steamManifestProc
    stdout: StdioCollector {
      onStreamFinished: {
        var scan = Gaming.parseSteamManifestScan(text);
        root.steamGameCount = scan.count;
        root.steamDedicatedServers = scan.servers || [];
      }
    }
    stderr: StdioCollector {}
  }
  Process {
    id: bnetGameCountProc
    stdout: StdioCollector { onStreamFinished: root.bnetGameCount = Gaming.parseBattlenetGameCount(text) }
    stderr: StdioCollector {}
  }
  Process {
    id: steamDirProc
    onExited: function(code) { root.steamInstalled = (code === 0) }
  }
  Process {
    id: bnetDirProc
    onExited: function(code) { root.bnetInstalled = (code === 0) }
  }
  FileView {
    id: steamVdfView
    printErrors: false
    onLoaded: {
      var paths = Gaming.parseLibraryPaths(text());
      var dirs = [];
      for (var i = 0; i < paths.length; i++) {
        var p = Shell.trim(paths[i]);
        if (p.length > 0)
          dirs.push(p + "/steamapps");
      }
      if (dirs.length === 0) {
        var steamRoot = Gaming.steamRootPath(root.homeDir);
        dirs = [steamRoot + "/steamapps", "/mnt/games/SteamLibrary/steamapps"];
      }
      steamManifestProc.running = false;
      steamManifestProc.command = Gaming.steamManifestCountCommandForDirs(dirs);
      steamManifestProc.running = true;
      root.steamNote = "Steam libraries detected: " + dirs.length + " (filtered installed games across libraries).";
    }
    onLoadFailed: {
      root.steamNote = "Counting installed games from default/common libraries.";
    }
  }

  Process {
    id: extraAppsScanProc
    stdout: StdioCollector {
      onStreamFinished: {
        root.extraApps = Gaming.parseScan(text, Gaming.catalog());
      }
    }
    stderr: StdioCollector {}
    onExited: function(code) {
      root.extraAppsScanBusy = false;
      if (code !== 0 && (!root.extraApps || root.extraApps.length === 0)) {
        root.extraApps = Gaming.parseScan("", Gaming.catalog());
      }
    }
  }

  Process {
    id: extraAppLaunchProc
    property string appId: ""
    property string appName: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) {
        root.lastActionMessage = "Launched " + (appName || appId) + ".";
      } else {
        var err = Shell.trim(stderr.text || "");
        root.lastActionMessage = "Failed to launch " + (appName || appId) + (err.length > 0 ? (": " + err) : (" (code " + code + ")."));
      }
      root.refreshGames();
    }
  }

  // Launches the interactive install terminal (its own exit is not the install result)
  Process {
    id: installTerminalProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code !== 0 && root.installRunning && Shell.trim(root.installLog).length === 0) {
        root.finishInstall(null);
        root.extraAppInstallStatus = "Could not open the install terminal. Check that xdg-terminal-exec works.";
        root.lastActionMessage = root.extraAppInstallStatus;
      }
    }
  }

  // Streams the install log file written by the terminal wrapper
  Process {
    id: installLogProc
    function appendLine(line) {
      var t = Shell.stripAnsi(line);
      var m = t.match(/\[vember-install-exit:(-?\d*)\]/);
      if (m) {
        var codeStr = Shell.trim(m[1]);
        root.finishInstall(codeStr.length === 0 ? null : Number(codeStr));
        return;
      }
      if (Shell.trim(t).length === 0)
        return;
      var next = (root.installLog.length > 0 ? (root.installLog + "\n") : "") + t;
      if (next.length > 12000)
        next = next.slice(next.length - 12000);
      root.installLog = next;
    }
    stdout: SplitParser { onRead: function(line) { installLogProc.appendLine(line) } }
    stderr: SplitParser { onRead: function(line) { installLogProc.appendLine(line) } }
    onExited: function(code) {
      if (root.installRunning) {
        root.installRunning = false;
        // The stream can end without the exit marker (for example the log file
        // was removed). Stop the watchdog timers here too, or they keep firing
        // every 30s for the rest of the session.
        installNoOutputTimer.stop();
        installStallTimer.stop();
        if (Shell.trim(root.extraAppInstallStatus).indexOf("Installing") === 0)
          root.extraAppInstallStatus = "Install log stream ended.";
        root.lastActionMessage = root.extraAppInstallStatus;
      }
    }
  }

  // Reads the previous install title + log so it survives panel close/reload
  Process {
    id: installLogReadProc
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.installRunning)
          return;
        var raw = String(text || "");
        var stateMark = "---VEMBER-STATE---";
        var logMark = "---VEMBER-LOG---";
        var stateIdx = raw.indexOf(stateMark);
        var logIdx = raw.indexOf(logMark);
        var title = stateIdx >= 0 ? Shell.trim(raw.slice(0, stateIdx)) : Shell.trim(raw);
        var stateBlock = (stateIdx >= 0 && logIdx > stateIdx)
          ? raw.slice(stateIdx + stateMark.length, logIdx) : "";
        var body = logIdx >= 0 ? raw.slice(logIdx + logMark.length) : raw;
        var stateLines = stateBlock.split("\n");
        var state = Shell.trim(stateLines[0] || "");
        var runningId = Shell.trim(stateLines[1] || "");
        var parsed = InstallLog.parse(body, 12000);
        if (title.length > 0)
          root.installTitle = title;
        root.installLog = parsed.text;
        if (state === "ALIVE" && runningId.length > 0) {
          // The terminal is still working: reattach instead of showing a frozen log
          root.installRunning = true;
          root.installRunningId = runningId;
          if (runningId.indexOf("dev:") === 0) {
            root.devInstallBusy = true;
            root.devInstallToolId = runningId.slice(4);
          }
          root.extraAppInstallStatus = "Reattached to the running install. Live output below.";
          if (root.installIsDev) {
            root.devInstallStatus = root.extraAppInstallStatus;
            root.devStatus = root.devInstallStatus;
          }
          root.lastActionMessage = root.extraAppInstallStatus;
          installLogProc.running = false;
          installLogProc.command = ["tail", "-n", "+1", "-F", InstallLog.logPath(root.homeDir)];
          installLogProc.running = true;
          // The lock proves the terminal opened, so only nudge for prompts;
          // the watchdog verifies liveness on its own and must run for a
          // reattached install too, or a terminal closed after the panel
          // reloaded would never be noticed.
          installNoOutputTimer.restart();
          installStallTimer.restart();
          return;
        }
        if (Shell.trim(root.extraAppInstallStatus).length === 0 && parsed.text.length > 0) {
          var label = title.length > 0 ? title.replace(/^Vember Install:\s*/, "") : "Install";
          if (parsed.finished) {
            if (parsed.exitCode === 0)
              root.extraAppInstallStatus = label + " finished.";
            else if (parsed.exitCode === null || isNaN(parsed.exitCode))
              root.extraAppInstallStatus = label + " finished (exit code unknown).";
            else
              root.extraAppInstallStatus = label + " failed (exit code " + parsed.exitCode + ").";
          } else {
            root.extraAppInstallStatus = "Previous install log loaded.";
          }
        }
      }
    }
    stderr: StdioCollector {}
  }

  // Clears the persisted install title/log files
  Process {
    id: installClearProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  Timer {
    id: installRefreshTimer
    interval: 2500
    repeat: false
    onTriggered: root.refreshAfterInstall()
  }

  Timer {
    id: installRefreshTimer2
    interval: 9000
    repeat: false
    onTriggered: root.refreshAfterInstall()
  }

  Timer {
    id: installNoOutputTimer
    interval: 5000
    repeat: false
    onTriggered: {
      if (!root.installRunning || Shell.trim(root.installLog).length > 0)
        return;
      root.extraAppInstallStatus = "No output yet — check the terminal window for a password or y/n prompt.";
      root.lastActionMessage = root.extraAppInstallStatus;
    }
  }

  // Watchdog: the wrapper writes its pid to the lock file before it runs the
  // install and removes it only after writing the exit marker. So the lock
  // answers "is the terminal still working?" whether or not the log has output.
  //
  // This must NOT depend on the log being empty. A terminal killed midway
  // leaves output behind and a `tail -F` that never ends, and the panel used
  // to sit on "running" forever because the old check bailed out as soon as a
  // single line had arrived. Checking liveness directly means a live install
  // (including one waiting on a password prompt) is never stopped, while a
  // dead one is noticed within one interval.
  Timer {
    id: installStallTimer
    interval: 30000
    repeat: true
    onTriggered: {
      if (!root.installRunning)
        return;
      // The install lock stores id on line 1 and pid on line 2.
      installLockCheckProc.command =
        InstallLog.lockCheckCommand(InstallLog.lockPath(root.homeDir), 2);
      installLockCheckProc.running = true;
    }
  }

  Process {
    id: installLockCheckProc
    onExited: function(code) {
      if (!root.installRunning)
        return;
      var hasOutput = Shell.trim(root.installLog).length > 0;
      var verdict = InstallLog.watchdogVerdict(code, hasOutput);
      if (verdict === "alive") {
        // Only nudge about a password prompt when nothing has been written
        // yet; otherwise leave the streamed output alone.
        if (!hasOutput) {
          root.extraAppInstallStatus = "Still waiting — the terminal may be asking for a password. Tracking continues.";
          root.lastActionMessage = root.extraAppInstallStatus;
        }
      } else if (verdict === "never-started") {
        // No lock and no output: the terminal never started. The tail would
        // otherwise wait on a file that will never be written.
        root.finishInstall(null);
        root.extraAppInstallStatus = "Could not open the install terminal. Check that xdg-terminal-exec works.";
        root.lastActionMessage = root.extraAppInstallStatus;
      } else if (verdict === "dead") {
        // Lock present, pid gone: the terminal was closed before the exit
        // marker was written, so tracking would never end on its own.
        root.stopInstall();
        root.extraAppInstallStatus = "The install terminal closed before finishing. Tracking stopped.";
        root.lastActionMessage = root.extraAppInstallStatus;
      }
      // "wait" (lock pid not written yet) and "teardown" (lock gone, output
      // present) both do nothing: the next tick or `tail` resolves them.
    }
  }

  // --- Processes: Game mount ---
  Process {
    id: findmntProc
    command: SystemInfo.findmntCommand(root.gameMount)
    stdout: StdioCollector {
      onStreamFinished: {
        var info = SystemInfo.parseFindmnt(text);
        root.gameMountPresent = !!info;
      }
    }
    onExited: function(code) {
      if (code !== 0) root.gameMountPresent = false;
    }
  }
  Process {
    id: dfProc
    command: SystemInfo.dfBytesCommand(root.gameMount)
    stdout: StdioCollector {
      onStreamFinished: {
        var info = SystemInfo.parseDfBytes(text);
        if (info) {
          root.gameMountPresent = true;
          root.gameMountUsedBytes = info.usedBytes;
          root.gameMountAvailBytes = info.availBytes;
          root.gameMountTotalBytes = info.totalBytes;
          root.gameMountUseRatio = info.totalBytes > 0 ? Math.max(0, Math.min(1, info.usedBytes / info.totalBytes)) : 0;
          root.gameMountUsePercentText = Shell.trim(info.usePercent);
          root.gameMountSummary = Shell.humanBytes(info.usedBytes) + " used / "
            + Shell.humanBytes(info.availBytes) + " free / "
            + Shell.humanBytes(info.totalBytes) + " total (" + info.usePercent + ")";
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (Shell.trim(text).length > 0) root.gameMountError = Shell.trim(text)
    }
  }

  Timer {
    id: pollTimer
    interval: 15000
    repeat: true
    running: root.opened
    onTriggered: root.refreshAll()
  }

  Timer {
    id: hotReloadDebounce
    interval: 900
    repeat: false
    onTriggered: root.hotReloadHub()
  }

  function scheduleHotReload() {
    hotReloadDebounce.restart();
  }

  Component.onCompleted: {
    loadManifestInfo();
    loadHubConfig();
    loadOmarchyUpdateLog();
    loadInstallLog();
  }

  Process {
    id: manifestReadProc
    command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "sh", Quickshell.env("HOME") + "/.config/omarchy/plugins/elena.vember-server-hub/manifest.json"]
    stdout: StdioCollector {
      onStreamFinished: {
        // This reads manifest.json, not config.json. Parsing it as a hub
        // config (the old behaviour) returned state "wizard" and raced the
        // real config loader, blanking the server name and reopening the
        // first-run wizard. It only sets the manifest the version binds to.
        var m = Config.parseManifest(text);
        if (m) root.manifest = m;
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: configReadProc
    command: ["sh", "-c", "if [ -f \"$1\" ]; then cat \"$1\"; fi", "sh", root.configPath]
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = Shell.trim(text);
        if (raw.length === 0) {
          root.configReady = false;
          root.serverName = "";
          root.serverRole = "";
          root.openWizard(root.defaultServerName());
          return;
        }
        try {
          var obj = JSON.parse(raw);
          var name = Shell.trim(obj && obj.serverName ? obj.serverName : "");
          var role = Shell.trim(obj && obj.serverRole ? obj.serverRole : "");
          var editor = Shell.trim(obj && obj.preferredEditor ? obj.preferredEditor : "");
          var order = root.normalizedTabOrder(obj && obj.tabOrder ? obj.tabOrder : root.tabOrder);
          var cfgPort = Number(obj && obj.codeServerPort ? obj.codeServerPort : 8443);
          if (!isFinite(cfgPort)) cfgPort = 8443;
          cfgPort = Math.round(cfgPort);
          if (cfgPort < 1 || cfgPort > 65535) cfgPort = 8443;
          root.codeServerPort = cfgPort;
          root.tabOrder = order;
          if (name.length > 0) {
            root.serverName = name;
            root.serverNameDraft = name;
            root.serverRole = role;
            root.serverRoleDraft = role;
            root.preferredEditor = editor;
            root.configReady = true;
            root.wizardOpen = false;
          } else {
            root.configReady = false;
            root.serverName = "";
            root.serverRole = "";
            root.preferredEditor = editor;
            root.openWizard(root.defaultServerName());
          }
        } catch (e) {
          root.configReady = false;
          root.serverName = "";
          root.serverRole = "";
          root.preferredEditor = "";
          root.tabOrder = root.normalizedTabOrder([]);
          root.codeServerPort = 8443;
          root.openWizard(root.defaultServerName());
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        // ignore; missing config handled as first use
      }
    }
  }

  Timer {
    id: serverNameRestartTimer
    interval: 700
    repeat: false
    onTriggered: {
      root.requestClose();
      serverNameReopenTimer.restart();
    }
  }

  Timer {
    id: serverNameReopenTimer
    interval: 350
    repeat: false
    onTriggered: {
      root.restartingForServerName = false;
      root.open();
    }
  }

  Process {
    id: configWriteProc
    stdout: StdioCollector {}
    stderr: StdioCollector {
      onStreamFinished: {
        var err = Shell.trim(text);
        if (err.length > 0) {
          root.lastActionMessage = "Failed to save hub config: " + err;
          root.restartingForServerName = false;
          root.pendingConfigRestart = false;
        }
      }
    }
    onExited: function(code) {
      if (code === 0) {
        if (root.pendingConfigRestart) {
          root.lastActionMessage = "Server name saved. Restarting Server Hub…";
          serverNameRestartTimer.restart();
        } else {
          root.lastActionMessage = "Hub settings saved.";
        }
      } else {
        root.restartingForServerName = false;
      }
      root.pendingConfigRestart = false;
    }
  }

  // --- Processes: Dev ---
  Process {
    id: devToolsProc
    command: DevTools.checkCommand()
    stdout: StdioCollector {
      onStreamFinished: {
        root.devTools = DevTools.parseChecks(text);
        if (root.devToolsOnlyRefresh) {
          root.devToolsOnlyRefresh = false;
          codeServerProc.running = false;
          codeServerProc.running = true;
        } else {
          devReposProc.running = false;
          devReposProc.running = true;
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        var err = Shell.trim(text);
        if (err.length > 0) root.devError = err;
      }
    }
    onExited: function(code) {
      if (code !== 0 && root.devTools.length === 0)
        root.devError = "Failed to detect dev tools (code " + code + ").";
      if (code !== 0 && root.devToolsOnlyRefresh) {
        root.devToolsOnlyRefresh = false;
        root.devBusy = false;
      }
    }
  }
  Process {
    id: devReposProc
    command: DevTools.reposScanCommand(root.homeDir)
    stdout: StdioCollector {
      onStreamFinished: {
        root.devRepos = DevTools.parseRepos(text);
      }
    }
    stderr: StdioCollector {}
    onExited: function(code) {
      // chain code-server status check
      codeServerProc.running = false;
      codeServerProc.running = true;
    }
  }
  Process {
    id: codeServerProc
    command: DevTools.codeServerPsCommand()
    stdout: StdioCollector {
      onStreamFinished: {
        var info = DevTools.parseCodeServerStatus(text);
        root.codeServerPresent = !!info.present;
        root.codeServerRunning = !!info.running;
        root.codeServerState = info.state || "unknown";
        root.codeServerStatusText = info.status || "";
        root.codeServerImage = info.image || "";
      }
    }
    stderr: StdioCollector {}
    onExited: function(code) {
      root.devBusy = false;
      var base = root.devToolsOnlyRefresh ? "Dev tools refreshed." : ("Found " + root.devRepos.length + " repo(s).");
      if (Shell.trim(root.devInstallStatus).length === 0 || root.devToolsOnlyRefresh)
        root.devStatus = base + " VS Code Server: " + (root.codeServerPresent ? root.codeServerState : "not set up") + ".";
      else
        root.devStatus = root.devInstallStatus + " VS Code Server: " + (root.codeServerPresent ? root.codeServerState : "not set up") + ".";
      root.codeServerBusy = false;
    }
  }
  Process {
    id: devInstallSilentProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.devInstallBusy = false;
      var label = DevTools.label(root.devInstallToolId);
      var err = Shell.trim(devInstallSilentProc.stderr.text || "");
      var out = Shell.trim(devInstallSilentProc.stdout.text || "");
      if (code === 0) {
        root.devInstallStatus = label + " installed. Refreshing…";
        root.devStatus = root.devInstallStatus;
      } else {
        var msg = err.length > 0 ? err : out;
        if (msg.length > 120) msg = msg.slice(0, 120) + "…";
        root.devInstallStatus = label + " install failed" + (msg.length > 0 ? (": " + msg) : (" (code " + code + ")")) + ". Try terminal install.";
        root.devStatus = root.devInstallStatus;
      }
      root.devInstallToolId = "";
      // targeted refresh of dev tools section (and code-server status cheap enough)
      root.refreshDevTools();
      codeServerProc.running = false;
      codeServerProc.running = true;
    }
  }
  Process {
    id: devOpenRepoProc
    property string repoPath: ""
    property string editorId: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      var label = DevTools.label(editorId);
      if (code === 0) {
        var out = Shell.trim(stdout.text || "");
        var bin = out.indexOf("BIN=") === 0 ? Shell.trim(out.slice(4)) : "";
        root.devStatus = "Opened " + repoPath + " in " + label + (bin.length > 0 ? (" (" + bin + ")") : "") + ".";
        root.lastActionMessage = "Opened in " + label + ".";
      } else {
        var err = Shell.trim(stderr.text || "");
        var msg = err.length > 0 ? err : ("Failed to open in " + label + " (code " + code + ").");
        root.devStatus = msg;
        root.lastActionMessage = msg;
      }
    }
  }

  Process {
    id: devRepoDetailProc
    property string repoPath: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (repoPath !== root.devSelectedRepoPath)
        return;
      root.devRepoDetailBusy = false;
      if (code === 0) {
        root.devRepoDetail = DevTools.parseRepoDetail(stdout.text || "");
      } else {
        // Include git's own reason: a permissions problem and a missing
        // repository look identical as "code 1".
        root.devRepoDetail = { error: Shell.failureMessage(
          "Failed to load repo details", code, devRepoDetailProc.stderr.text) };
      }
    }
  }

  Timer {
    id: codeServerSetupPollTimer
    interval: 3000
    repeat: true
    running: false
    onTriggered: {
      if (root.codeServerSetupPollsLeft <= 0) {
        running = false;
        if (root.codeServerSetupStage === "starting") {
          root.codeServerBusy = false;
          root.codeServerSetupStage = "error";
          root.codeServerSetupProgress = 0;
          root.codeServerSetupDetail = "Container did not reach running state in time. See debug log/status.";
          root.codeServerStatusText = root.codeServerSetupDetail;
          root.devStatus = root.codeServerSetupDetail;
          root._appendCodeServerSetupLog(root.codeServerSetupDetail);
        }
        return;
      }
      root.codeServerSetupPollsLeft -= 1;
      root.refreshCodeServer();
      root.refreshDocker();
      if (root.codeServerRunning) {
        running = false;
        if (root.codeServerSetupProvisionAfterStart) {
          root.codeServerSetupProvisionAfterStart = false;
          root.codeServerSetupStage = "provisioning";
          root.codeServerSetupProgress = -1;
          root.codeServerSetupDetail = "Installing uv, Python tools, and extensions inside the container…";
          root.codeServerStatusText = root.codeServerSetupDetail;
          root._appendCodeServerSetupLog("Container running. Provisioning tools and extensions…");
          var prov = [
            "set -e",
            "echo 'Provisioning code-server environment…'",
            "export PATH=/home/coder/.local/bin:$PATH",
            "if ! command -v uv >/dev/null 2>&1; then echo 'Installing uv…'; curl -LsSf https://astral.sh/uv/install.sh | sh; else echo 'uv already installed.'; fi",
            "sudo install -m 755 /home/coder/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true",
            "sudo install -m 755 /home/coder/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true",
            "if command -v uv >/dev/null 2>&1; then uv --version || true; fi",
            "if ! command -v python3 >/dev/null 2>&1; then echo 'Installing python3, pip, venv (apt)…'; sudo apt-get update; sudo apt-get install -y python3 python3-pip python3-venv; else echo 'python3 already installed.'; python3 --version || true; fi",
            "if ! command -v gh >/dev/null 2>&1; then",
            "  echo 'Installing GitHub CLI (gh)…'",
            "  sudo apt-get update",
            "  if ! sudo apt-get install -y gh; then",
            "    echo 'gh not available in default repos, adding GitHub CLI apt repo…'",
            "    sudo apt-get install -y curl ca-certificates",
            "    sudo mkdir -p -m 755 /etc/apt/keyrings",
            "    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null",
            "    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg",
            "    echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null",
            "    sudo apt-get update",
            "    sudo apt-get install -y gh",
            "  fi",
            "else",
            "  echo 'gh already installed.'",
            "fi",
            "if command -v gh >/dev/null 2>&1; then gh --version || true; fi",
            "echo 'Installing VS Code extensions (ms-python.python, ms-python.debugpy, charliermarsh.ruff)…'",
            "code-server --install-extension ms-python.python --force || true",
            "code-server --install-extension ms-python.debugpy --force || true",
            "code-server --install-extension charliermarsh.ruff --force || true",
            "echo 'Provisioning complete.'"
          ].join("\n");
          codeServerSetupProvisionProc.running = false;
          codeServerSetupProvisionProc.command = ["docker", "exec", DevTools.codeServerContainer(), "bash", "-lc", prov];
          codeServerSetupProvisionProc.running = true;
        } else {
          root.codeServerBusy = false;
          root.codeServerSetupStage = "done";
          root.codeServerSetupProgress = 1;
          root.codeServerSetupDetail = "VS Code Server is running on port " + root.codeServerPort + ".";
          root.codeServerStatusText = root.codeServerSetupDetail;
          root.devStatus = "VS Code Server ready at http://localhost:" + root.codeServerPort;
          root._appendCodeServerSetupLog("Ready: running on port " + root.codeServerPort);
        }
      }
    }
  }

  Process {
    id: codeServerSetupPrepProc
    stdout: SplitParser {
      onRead: function(line) {
        root._appendCodeServerSetupLog(line);
      }
    }
    stderr: SplitParser {
      onRead: function(line) {
        root._appendCodeServerSetupLog("ERR: " + line);
      }
    }
    onExited: function(code) {
      if (code === 0) {
        // READY
        root.codeServerSetupStage = "pulling";
        root.codeServerSetupProgress = 0;
        root.codeServerSetupDetail = "Pulling image codercom/code-server:latest…";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root._appendCodeServerSetupLog("Preflight OK. Pulling image…");
        root._codeServerPullLayers = ({});
        codeServerSetupPullProc.running = false;
        codeServerSetupPullProc.command = ["docker", "pull", "codercom/code-server:latest"];
        codeServerSetupPullProc.running = true;
      } else if (code === 10) {
        root.codeServerSetupStage = "exists";
        root.codeServerSetupProgress = 0;
        root.codeServerSetupDetail = "Container already exists. Password/env saved; Uninstall then Set up to apply port/password on a new container.";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root.codeServerBusy = false;
        root.refreshCodeServer();
      } else {
        root.codeServerBusy = false;
        root.codeServerSetupStage = "error";
        root.codeServerSetupProgress = 0;
        var msg = "Setup preflight failed (code " + code + "). See debug log.";
        if (code === 11) msg = "Docker is not installed or not in PATH.";
        else if (code === 12) msg = "Docker is not running or not accessible.";
        root.codeServerSetupDetail = msg;
        root.codeServerStatusText = msg;
        root.devStatus = msg;
        root._appendCodeServerSetupLog(msg);
        root.refreshCodeServer();
      }
    }
  }

  Process {
    id: codeServerSetupPullProc
    stdout: SplitParser {
      onRead: function(line) {
        root._appendCodeServerSetupLog(line);
        root._updateCodeServerPullProgressFromLine(line);
      }
    }
    stderr: SplitParser {
      onRead: function(line) {
        root._appendCodeServerSetupLog(line);
        root._updateCodeServerPullProgressFromLine(line);
      }
    }
    onExited: function(code) {
      if (code === 0) {
        root.codeServerSetupStage = "creating";
        root.codeServerSetupProgress = 1;
        root.codeServerSetupBytesDone = root.codeServerSetupBytesTotal > 0 ? root.codeServerSetupBytesTotal : root.codeServerSetupBytesDone;
        root.codeServerSetupDetail = "Image ready. Creating container…";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root._appendCodeServerSetupLog("Image pull complete. Creating container…");
        var p = root.codeServerPort;
        var csConf = root.homeDir + "/.config/" + DevTools.codeServerContainer();
        codeServerSetupRunProc.command = ["docker", "run", "-d",
          "--name", DevTools.codeServerContainer(),
          "-p", String(p) + ":8080",
          "-v", csConf + ":/home/coder/.config",
          "-v", csConf + "/user-data:/home/coder/.local/share/code-server",
          "-v", csConf + "/bin:/home/coder/.local/bin",
          "-v", root.homeDir + ":/home/coder/home",
          "-e", "PATH=/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
          "--env-file", csConf + "/code-server.env",
          "--restart", "unless-stopped",
          "codercom/code-server:latest"];
        root.codeServerSetupProvisionAfterStart = true;
        codeServerSetupRunProc.running = true;
      } else {
        root.codeServerBusy = false;
        root.codeServerSetupStage = "error";
        root.codeServerSetupProgress = 0;
        root.codeServerSetupDetail = "Image pull failed (code " + code + "). See debug log.";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root.devStatus = root.codeServerSetupDetail;
        root.refreshCodeServer();
      }
    }
  }

  Process {
    id: codeServerSetupRunProc
    stdout: SplitParser {
      onRead: function(line) { root._appendCodeServerSetupLog(line); }
    }
    stderr: SplitParser {
      onRead: function(line) { root._appendCodeServerSetupLog("ERR: " + line); }
    }
    onExited: function(code) {
      if (code === 0) {
        root.codeServerSetupStage = "starting";
        root.codeServerSetupProgress = 1;
        root.codeServerSetupDetail = "Container created. Waiting for it to run…";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root._appendCodeServerSetupLog("Container created. Waiting for running state…");
        root.codeServerSetupPollsLeft = 40;
        codeServerSetupPollTimer.restart();
        root.refreshCodeServer();
        root.refreshDocker();
      } else {
        root.codeServerBusy = false;
        root.codeServerSetupStage = "error";
        root.codeServerSetupProgress = 0;
        root.codeServerSetupDetail = "Failed to create/start container (code " + code + "). See debug log.";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root.devStatus = root.codeServerSetupDetail;
        root.refreshCodeServer();
        root.refreshDocker();
      }
    }
  }

  Process {
    id: codeServerSetupProvisionProc
    stdout: SplitParser {
      onRead: function(line) { root._appendCodeServerSetupLog(line); }
    }
    stderr: SplitParser {
      onRead: function(line) { root._appendCodeServerSetupLog(line); }
    }
    onExited: function(code) {
      if (code === 0) {
        root.codeServerSetupStage = "done";
        root.codeServerSetupProgress = 1;
        root.codeServerSetupDetail = "VS Code Server is running with uv and Python extensions ready (port " + root.codeServerPort + ").";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root.devStatus = "VS Code Server ready at http://localhost:" + root.codeServerPort;
        root._appendCodeServerSetupLog("Provisioning finished successfully.");
      } else {
        root.codeServerSetupStage = "done";
        root.codeServerSetupProgress = 1;
        root.codeServerSetupDetail = "VS Code Server is running, but provisioning had issues (code " + code + "). Check debug log.";
        root.codeServerStatusText = root.codeServerSetupDetail;
        root.devStatus = "VS Code Server running (provisioning warnings).";
        root._appendCodeServerSetupLog("Provisioning finished with code " + code + " (some steps may have failed).");
      }
      root.codeServerBusy = false;
      root.refreshCodeServer();
      root.refreshDocker();
    }
  }

  Process {
    id: codeServerActionProc
    property string actionName: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.codeServerBusy = false;
      if (code === 0) {
        root.devStatus = "VS Code Server " + actionName + " succeeded.";
      } else {
        root.devStatus = Shell.failureMessage(
          "VS Code Server " + actionName + " failed", code, codeServerActionProc.stderr.text);
      }
      root.refreshCodeServer();
      root.refreshDocker();
    }
  }

  // --- Hot reload watchers ---
  // Every file that makes up the plugin. Saving any of them restarts the shell
  // and reopens the hub, so a change is one save away from being live.
  readonly property var watchedFiles: [
    "manifest.json", "Panel.qml", "HubPanel.qml", "BarWidget.qml",
    "model/Config.mjs", "model/DevTools.mjs", "model/Docker.mjs",
    "model/Gaming.mjs", "model/InstallLog.mjs", "model/Omarchy.mjs",
    "model/Shell.mjs", "model/Ssh.mjs", "model/Systemd.mjs",
    "model/SystemInfo.mjs", "model/Tailscale.mjs",
    "ui/ArrangeTabsDialog.qml", "ui/CodeServerRemoveDialog.qml",
    "ui/CodeServerSetupDialog.qml", "ui/PruneConfirmDialog.qml",
    "ui/ServerNameWizard.qml", "ui/SettingsMenu.qml",
    "ui/SshKeyConfirmDialog.qml", "ui/ToastStack.qml", "ui/UpdateDialog.qml",
    "ui/tabs/AccessTab.qml", "ui/tabs/ContainersTab.qml", "ui/tabs/DevTab.qml",
    "ui/tabs/GamesTab.qml", "ui/tabs/OverviewTab.qml"
  ]

  Instantiator {
    model: root.watchedFiles
    delegate: FileView {
      path: root.homeDir + "/.config/omarchy/plugins/elena.vember-server-hub/" + modelData
      printErrors: false
      watchChanges: true
      onFileChanged: root.scheduleHotReload()
    }
  }

  // --- Plugin self-update processes/timers ---
  Timer {
    id: pluginUpdateCheckTimer
    interval: 5 * 60 * 1000
    repeat: true
    running: root.opened
    onTriggered: if (!root.updateCheckBusy && !root.pluginUpdateBusy) root.checkPluginUpdate(false)
  }

  Timer {
    id: pluginUpdateStartupCheckTimer
    interval: 4000
    repeat: false
    running: true
    onTriggered: root.checkPluginUpdate(false)
  }

  Timer {
    id: pluginUpdatePunTimer
    interval: 2200
    repeat: true
    running: false
    onTriggered: {
      if (root.pluginUpdateBusy) root.pluginUpdatePun = root._nextPluginUpdatePun();
      else running = false;
    }
  }

  Process {
    id: pluginRepoResolveProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      var dir = Shell.trim(stdout.text || "");
      if (dir.length === 0) dir = root.homeDir + "/Projects/vember-server";
      root.pluginRepoDir = dir;
      pluginUpdateAheadProc.running = false;
      pluginUpdateAheadProc.command = ["sh", "-c",
        "cd \"$1\" || exit 1; " +
        "git fetch origin --quiet >/dev/null 2>&1 || true; " +
        "git rev-list --count HEAD..@{upstream} 2>/dev/null || git rev-list --count HEAD..origin/master 2>/dev/null || echo 0",
        "sh", dir];
      pluginUpdateAheadProc.running = true;
    }
  }

  Process {
    id: pluginUpdateAheadProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.updateCheckBusy = false;
      var n = Number(Shell.trim(stdout.text || "0"));
      if (isNaN(n) || n < 0) n = 0;
      root.pluginUpdateRemoteCommits = n;
      root.updateAvailable = n > 0;
      root.updateAvailableBuild = n > 0 ? (String(n) + " new commit" + (n === 1 ? "" : "s")) : "";
      if (n > 0) {
        root.pluginUpdateStatus = "Update ready on GitHub (" + root.updateAvailableBuild + ").";
      } else if (Shell.trim(root.pluginUpdateStatus) === "Checking for updates…") {
        root.pluginUpdateStatus = "You’re up to date.";
      }
    }
  }

  Process {
    id: pluginUpdateFetchProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code !== 0) {
        root.pluginUpdateBusy = false;
        pluginUpdatePunTimer.running = false;
        root.pluginUpdateProgress = 0;
        var err = Shell.trim(stderr.text || stdout.text || "");
        root.pluginUpdateError = err.length > 0 ? err : ("git fetch failed (code " + code + ").");
        root.pluginUpdateStatus = "Update failed: " + root.pluginUpdateError;
        root.pluginUpdatePun = "Well, that didn’t ship. Check the status above.";
        return;
      }
      root.pluginUpdateProgress = 0.45;
      root.pluginUpdatePun = "Fetched! Now pulling the good stuff…";
      pluginUpdatePullProc.running = false;
      pluginUpdatePullProc.command = ["sh", "-c", "cd \"$1\" && git pull --ff-only 2>&1", "sh", root._resolvedPluginRepoDir()];
      pluginUpdatePullProc.running = true;
    }
  }

  Process {
    id: pluginUpdatePullProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.pluginUpdateBusy = false;
      pluginUpdatePunTimer.running = false;
      if (code === 0) {
        root.pluginUpdateProgress = 1;
        root.updateAvailable = false;
        root.pluginUpdateRemoteCommits = 0;
        root.updateAvailableBuild = "";
        var out = Shell.trim(stdout.text || "");
        root.pluginUpdateStatus = "Update complete. Reload the hub to apply changes." + (out.length > 0 ? "" : "");
        root.pluginUpdatePun = "All patched up! Time for a quick reload dance.";
      } else {
        root.pluginUpdateProgress = 0;
        var err = Shell.trim(stderr.text || stdout.text || "");
        root.pluginUpdateError = err.length > 0 ? err : ("git pull failed (code " + code + ").");
        root.pluginUpdateStatus = "Update failed: " + root.pluginUpdateError;
        root.pluginUpdatePun = "Update hit a snag. The repo might have local changes or need attention.";
      }
    }
  }

  HubPanel {
    hub: root
  }
}
