import QtQuick
import Quickshell
import Quickshell.Io
import "model/HubModel.js" as HubModel

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

  property string pluginVersion: "0.1.0"
  property int pluginBuild: 1
  property string serverName: ""
  property string serverNameDraft: ""
  property string serverRole: ""
  property string serverRoleDraft: ""
  property string preferredEditor: ""
  property var tabOrder: ["overview", "access", "containers", "games", "dev"]
  property bool configReady: false
  property bool wizardOpen: false
  property bool restartingForServerName: false
  property bool pendingConfigRestart: false
  property bool updateAvailable: false
  property string updateAvailableVersion: ""
  property string updateAvailableBuild: ""

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

  property bool steamInstalled: false
  property bool steamRunning: false
  property int steamGameCount: -1
  property string steamNote: ""

  property bool bnetInstalled: false
  property bool bnetRunning: false
  property int bnetGameCount: -1
  property string bnetNote: ""

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

  property bool codeServerPresent: false
  property bool codeServerRunning: false
  property string codeServerState: "unknown"
  property string codeServerStatusText: ""
  property string codeServerImage: ""
  property bool codeServerBusy: false
  property int codeServerPort: 8443

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

  function defaultServerName() {
    return HubModel.trimText(Quickshell.env("HOSTNAME") || "vemberos") || "vemberos";
  }

  function loadManifestInfo() {
    if (!manifestReadProc.running) manifestReadProc.running = true;
  }

  function loadHubConfig() {
    configReady = false;
    if (!configReadProc.running) configReadProc.running = true;
  }

  function openWizard(defaultName) {
    serverNameDraft = HubModel.trimText(defaultName || serverName || defaultServerName());
    serverRoleDraft = HubModel.trimText(serverRole || "");
    wizardOpen = true;
  }

  function normalizedTabOrder(order) {
    var defaults = ["overview", "access", "containers", "games", "dev"];
    var out = [];
    var seen = {};
    var src = order || [];
    for (var i = 0; i < src.length; i++) {
      var id = HubModel.trimText(src[i]);
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
    configWriteProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\"; printf '%s' \"$1\" > \"$2\"", "sh", payload, root.configPath];
    configWriteProc.running = true;
  }

  function moveTab(tabId, delta) {
    var order = normalizedTabOrder(tabOrder);
    var idx = order.indexOf(tabId);
    var nextIdx = idx + delta;
    if (idx < 0 || nextIdx < 0 || nextIdx >= order.length) return;
    var tmp = order[idx];
    order[idx] = order[nextIdx];
    order[nextIdx] = tmp;
    tabOrder = order;
    if (configReady || HubModel.trimText(serverName).length > 0)
      writeHubConfig(false);
  }

  function saveServerName(name) {
    var n = HubModel.trimText(name);
    if (n.length === 0)
      n = defaultServerName();
    var r = HubModel.trimText(serverRoleDraft);
    serverName = n;
    serverNameDraft = n;
    serverRole = r;
    serverRoleDraft = r;
    wizardOpen = false;
    configReady = true;
    writeHubConfig(false);
  }

  function setPreferredEditor(editorId) {
    preferredEditor = HubModel.trimText(editorId);
    if (configReady || HubModel.trimText(serverName).length > 0)
      writeHubConfig(false);
  }

  function openRepoInEditor(repoPath) {
    var path = HubModel.trimText(repoPath);
    if (path.length === 0) return;
    var editor = HubModel.trimText(preferredEditor);
    if (editor.length === 0) {
      devStatus = "Select a preferred editor in Dev tab to open repositories.";
      return;
    }
    var cmd = "";
    if (editor === "zed") cmd = "command -v zed >/dev/null 2>&1 && zed \"$1\" >/dev/null 2>&1 & || command -v zeditor >/dev/null 2>&1 && zeditor \"$1\" >/dev/null 2>&1 &";
    else if (editor === "vscode") cmd = "command -v code >/dev/null 2>&1 && code \"$1\" >/dev/null 2>&1 & || command -v code-oss >/dev/null 2>&1 && code-oss \"$1\" >/dev/null 2>&1 &";
    else cmd = "echo 'Unsupported editor: " + editor + "'";
    devOpenRepoProc.repoPath = path;
    devOpenRepoProc.running = false;
    devOpenRepoProc.command = ["sh", "-c", cmd, "sh", path];
    devOpenRepoProc.running = true;
    devStatus = "Opening " + path + " in " + HubModel.devToolLabel(editor) + "…";
  }

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

  function setupCodeServerTerminal(password, port) {
    var pass = HubModel.trimText(password);
    if (pass.length === 0) {
      codeServerStatusText = "Set a password for Code Server before setup.";
      lastActionMessage = "Code Server setup needs a password.";
      return;
    }
    var p = Number(port);
    if (!isFinite(p) || Math.round(p) < 1 || Math.round(p) > 65535) p = Number(codeServerPort);
    if (!isFinite(p) || Math.round(p) < 1 || Math.round(p) > 65535) p = 8443;
    p = Math.round(p);
    codeServerPort = p;
    if (configReady || HubModel.trimText(serverName).length > 0) writeHubConfig(false);

    codeServerBusy = true;
    codeServerStatusText = "Opening terminal to set up VS Code Server on port " + p + "…";
    codeServerActionProc.actionName = "setup";
    var inner = [
      "set -e",
      "PASS=\"$1\"",
      "PORT=\"$2\"",
      "mkdir -p \"$HOME/.config/vember-code-server\" \"$HOME/Projects\"",
      "if docker ps -a --format '{{.Names}}' | grep -qx 'vember-code-server'; then",
      "  echo 'Container vember-code-server already exists.'",
      "  echo 'State:' $(docker inspect -f '{{.State.Status}}' vember-code-server 2>/dev/null || echo unknown)",
      "  echo 'Ports:' $(docker port vember-code-server 2>/dev/null || echo unknown)",
      "  echo ''",
      "  echo 'To change port/password, Uninstall the container in the hub, then run Set up again.'",
      "else",
      "  if ! command -v docker >/dev/null 2>&1; then echo 'Docker is not installed or not in PATH.'; exit 1; fi",
      "  if ! docker info >/dev/null 2>&1; then echo 'Docker is installed but not running or not accessible (try: sudo systemctl start docker, and ensure your user can access docker).'; exit 1; fi",
      "  docker run -d --name vember-code-server -p \"$PORT:8080\" -v \"$HOME/.config/vember-code-server:/home/coder/.config\" -v \"$HOME:/home/coder/home\" -e PASSWORD=\"$PASS\" --restart unless-stopped codercom/code-server:latest",
      "  echo ''",
      "  echo 'VS Code Server started.'",
      "  echo \"URL: http://localhost:$PORT\"",
      "  echo 'Password: (the one you set in the hub)'",
      "  echo ''",
      "  echo 'Config kept in ~/.config/vember-code-server'",
      "fi"
    ].join("\n") + "\necho\necho 'Press Enter to close...'\nread -r _close || true";
    codeServerActionProc.command = ["sh", "-c",
      "/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation bash -lc \"$1\" _ \"$2\" \"$3\" </dev/null >/dev/null 2>&1 &",
      "sh", inner, pass, String(p)];
    codeServerActionProc.running = true;
  }

  function startCodeServer() {
    if (codeServerBusy) return;
    codeServerBusy = true;
    codeServerActionProc.actionName = "start";
    codeServerActionProc.command = ["docker", "start", "vember-code-server"];
    codeServerActionProc.running = true;
  }

  function stopCodeServer() {
    if (codeServerBusy) return;
    codeServerBusy = true;
    codeServerActionProc.actionName = "stop";
    codeServerActionProc.command = ["docker", "stop", "vember-code-server"];
    codeServerActionProc.running = true;
  }

  function uninstallCodeServer() {
    if (codeServerBusy) return;
    codeServerBusy = true;
    codeServerActionProc.actionName = "uninstall";
    codeServerActionProc.command = ["docker", "rm", "-f", "vember-code-server"];
    codeServerActionProc.running = true;
  }

  function openCodeServer() {
    Qt.openUrlExternally("http://localhost:" + codeServerPort);
  }

  function refreshDevTools() {
    devToolsProc.running = false;
    devToolsProc.running = true;
  }

  function runDevInstallSilent(toolId) {
    if (devInstallBusy) return;
    var label = HubModel.devToolLabel(toolId);
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
    var label = HubModel.devToolLabel(toolId);
    var cmd = "";
    if (toolId === "uv") cmd = "curl -LsSf https://astral.sh/uv/install.sh | sh";
    else if (toolId === "python") cmd = "sudo pacman -S --needed python python-pip";
    else if (toolId === "gh") cmd = "sudo pacman -S --needed github-cli";
    else if (toolId === "zed") cmd = "if command -v yay >/dev/null 2>&1; then yay -S --needed zed-preview-bin || yay -S --needed zed; else sudo pacman -S --needed zed; fi";
    else if (toolId === "vscode") cmd = "if command -v yay >/dev/null 2>&1; then yay -S --needed visual-studio-code-bin; else sudo pacman -S --needed code; fi";
    else cmd = "echo 'No install command configured for " + String(toolId) + "'";

    devInstallStatus = "Opening terminal to install " + label + "…";
    devStatus = devInstallStatus;
    devInstallProc.running = false;
    devInstallProc.command = ["sh", "-c",
      "/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation bash -lc " + JSON.stringify(cmd + "; echo; echo '---'; echo 'Press Enter to close...'; read -r") + " </dev/null >/dev/null 2>&1 &"];
    devInstallProc.running = true;
  }

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
    var key = HubModel.trimText(sshNewKeyText);
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

  function refreshGameMount() {
    gameMountError = "";
    if (!findmntProc.running) findmntProc.running = true;
    if (!dfProc.running) dfProc.running = true;
  }

  function refreshGames() {
    steamNote = "";
    bnetNote = "";
    var steamRoot = HubModel.steamRootPath(homeDir);
    steamInstalled = false;
    bnetInstalled = false;
    steamRunning = false;
    bnetRunning = false;
    steamGameCount = -1;
    bnetGameCount = -1;
    if (!steamPgrepProc.running) steamPgrepProc.running = true;
    if (!bnetPgrepProc.running) bnetPgrepProc.running = true;
    steamDirProc.command = ["test", "-d", steamRoot];
    if (!steamDirProc.running) steamDirProc.running = true;
    bnetDirProc.command = ["test", "-d", HubModel.battlenetPrefixPath(homeDir)];
    if (!bnetDirProc.running) bnetDirProc.running = true;
    // Baseline count: default + common external library; vdf load will refine to all libraries.
    var baselineDirs = [steamRoot + "/steamapps", "/mnt/games/SteamLibrary/steamapps"];
    steamManifestProc.running = false;
    steamManifestProc.command = HubModel.steamManifestCountCommandForDirs(baselineDirs);
    steamManifestProc.running = true;
    steamVdfView.path = "";
    steamVdfView.path = HubModel.steamLibraryVdfPath(homeDir);
    bnetGameCountProc.command = HubModel.battlenetGameCountCommand(homeDir);
    if (!bnetGameCountProc.running) bnetGameCountProc.running = true;
  }

  function runTailscaleAction(action) {
    if (tailscaleBusy)
      return;
    tailscaleBusy = true;
    tailscaleNote = "Running pkexec systemctl " + action + " tailscaled…";
    tsActionProc.actionName = action;
    tsActionProc.command = HubModel.pkexecSystemctlCommand(action, "tailscaled");
    tsActionProc.running = true;
  }

  function runTailscaleActionInTerminal(action) {
    tsTerminalProc.command = HubModel.terminalSystemctlCommand(action, "tailscaled");
    tsTerminalProc.running = true;
    tailscaleNote = "Opened terminal for: sudo systemctl " + action + " tailscaled";
  }

  function openOmarchyUpdateTerminal() {
    omarchyUpdateRunning = false;
    omarchyUpdateStatus = "Opening Omarchy update in terminal…";
    lastActionMessage = "Opened terminal: omarchy update.";
    omarchyUpdateProc.running = false;
    omarchyUpdateProc.command = ["sh", "-c",
      "/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation /usr/share/omarchy/bin/omarchy-update </dev/null >/dev/null 2>&1 &"];
    omarchyUpdateProc.running = true;
    closeAfterLaunchTimer.restart();
  }

  function runOmarchyUpdateInPanel() {
    omarchyUpdateLog = "";
    omarchyUpdateStatus = "Opening Omarchy update in terminal…";
    lastActionMessage = "Starting Omarchy update.";
    omarchyUpdateRunning = false;
    omarchyUpdateLogProc.running = false;
    omarchyUpdateProc.running = false;
    omarchyUpdateProc.command = ["sh", "-c",
      "/usr/share/omarchy/bin/omarchy-launch-floating-terminal-with-presentation /usr/share/omarchy/bin/omarchy-update </dev/null >/dev/null 2>&1 &"];
    omarchyUpdateProc.running = true;
    closeAfterLaunchTimer.restart();
  }

  function stopOmarchyUpdateLog() {
    omarchyUpdateLogProc.running = false;
    omarchyUpdateRunning = false;
    if (HubModel.trimText(omarchyUpdateStatus).indexOf("Starting") === 0 || HubModel.trimText(omarchyUpdateStatus).indexOf("Live log") === 0)
      omarchyUpdateStatus = "Live log stopped.";
  }

  function clearOmarchyUpdateLog() {
    omarchyUpdateLog = "";
    if (!omarchyUpdateRunning)
      omarchyUpdateStatus = "";
  }

  function runDockerAction(action, name) {
    if (dockerBusy)
      return;
    dockerBusy = true;
    dockerBusyName = name;
    dockerActionProc.actionName = action;
    dockerActionProc.containerName = name;
    dockerActionProc.command = HubModel.dockerActionCommand(action, name);
    dockerActionProc.running = true;
  }

  function runDockerPull(image, name) {
    if (dockerBusy)
      return;
    if (HubModel.trimText(image).length === 0) {
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
    dockerPullProc.command = HubModel.dockerPullCommand(image);
    dockerPullProc.running = true;
  }

  // --- Processes: Tailscale ---
  Process {
    id: tsActiveProc
    command: HubModel.systemctlIsActiveCommand("tailscaled")
    stdout: StdioCollector { onStreamFinished: root.tailscaleActive = HubModel.trimText(text) || "unknown" }
  }
  Process {
    id: tsEnabledProc
    command: HubModel.systemctlIsEnabledCommand("tailscaled")
    stdout: StdioCollector { onStreamFinished: root.tailscaleEnabled = HubModel.trimText(text) || "unknown" }
  }
  Process {
    id: tsIpProc
    command: HubModel.tailscaleIpCommand()
    stdout: StdioCollector { onStreamFinished: root.tailscaleIp = HubModel.nonEmptyLines(text).join(", ") }
  }
  Process {
    id: tsStatusProc
    command: HubModel.tailscaleStatusCommand()
    stdout: StdioCollector { onStreamFinished: root.tailscaleStatusText = HubModel.trimText(text) }
  }
  Process {
    id: tsStatusJsonProc
    command: HubModel.tailscaleStatusJsonCommand()
    stdout: StdioCollector {
      onStreamFinished: {
        var info = HubModel.parseTailscaleStatusJson(text);
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
      if (code === 0)
        root.tailscaleNote = "tailscaled " + actionName + " succeeded.";
      else
        root.tailscaleNote = "pkexec/systemctl " + actionName + " failed (code " + code + "). Try 'Run in terminal (sudo)'.";
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
    command: HubModel.systemctlIsActiveCommand("sshd")
    stdout: StdioCollector { onStreamFinished: root.sshActive = HubModel.trimText(text) || "unknown" }
  }
  Process {
    id: sshEnabledProc
    command: HubModel.systemctlIsEnabledCommand("sshd")
    stdout: StdioCollector { onStreamFinished: root.sshEnabled = HubModel.trimText(text) || "unknown" }
  }
  Process {
    id: sshHostKeysProc
    command: HubModel.sshHostKeyFingerprintsCommand()
    stdout: StdioCollector {
      onStreamFinished: root.sshHostKeys = HubModel.parseSshHostKeyFingerprints(text)
    }
  }
  Process {
    id: sshAuthorizedKeysProc
    command: HubModel.authorizedKeysReadCommand(root.homeDir)
    stdout: StdioCollector {
      onStreamFinished: {
        root.sshAuthorizedKeys = HubModel.parseAuthorizedKeys(text);
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
        var err = HubModel.trimText(sshAuthorizedKeysAddProc.stderr.text || "");
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
        var err = HubModel.trimText(sshAuthorizedKeysRemoveProc.stderr.text || "");
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
      var out = HubModel.trimText(sshGenerateKeyProc.stdout.text || "");
      var err = HubModel.trimText(sshGenerateKeyProc.stderr.text || "");
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
  Timer {
    id: closeAfterLaunchTimer
    interval: 250
    repeat: false
    onTriggered: root.requestClose()
  }
  Process {
    id: omarchyUpdateProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: omarchyUpdateLogProc
    function appendLog(line) {
      var t = String(line || "").replace(/\r/g, "");
      t = t.replace(/\x1B\[[0-?]*[ -\/]*[@-~]/g, "");
      t = t.replace(/\x1B\][^\x07]*(\x07|\x1B\\)/g, "");
      t = t.replace(/\x1B\[\?[0-9;]*[a-zA-Z]/g, "");
      if (HubModel.trimText(t).length === 0)
        return;
      var next = (root.omarchyUpdateLog.length > 0 ? (root.omarchyUpdateLog + "\n") : "") + t;
      if (next.length > 14000)
        next = next.slice(next.length - 14000);
      root.omarchyUpdateLog = next;
    }
    stdout: SplitParser { onRead: function(line) { omarchyUpdateLogProc.appendLog(line) } }
    stderr: SplitParser { onRead: function(line) { omarchyUpdateLogProc.appendLog(line) } }
    onExited: function(code) {
      root.omarchyUpdateRunning = false;
      if (HubModel.trimText(root.omarchyUpdateStatus).length === 0 || root.omarchyUpdateStatus.indexOf("Live log") === 0)
        root.omarchyUpdateStatus = "Live log stopped.";
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

  function hotReloadHub() {
    lastActionMessage = "Hot reloading: restarting shell and reopening hub…";
    hotReloadProc.running = false;
    hotReloadProc.running = true;
  }

  // --- Processes: Docker ---
  Process {
    id: dockerPsProc
    command: HubModel.dockerPsCommand()
    stdout: StdioCollector {
      onStreamFinished: root.dockerContainers = HubModel.parseDockerPs(text)
    }
    stderr: StdioCollector {
      onStreamFinished: if (HubModel.trimText(text).length > 0) root.dockerError = HubModel.trimText(text)
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
      if (code === 0)
        root.lastActionMessage = "Docker " + actionName + " succeeded: " + target;
      else
        root.lastActionMessage = "Docker " + actionName + " failed for " + target + " (code " + code + ").";
      root.refreshDocker();
    }
  }

  Process {
    id: dockerPullProc
    property string actionName: "pull"
    property string containerName: ""
    property string imageName: ""
    function handleLine(line) {
      var t = HubModel.trimText(line);
      if (t.length === 0)
        return;
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
      var target = containerName;
      var image = imageName;
      if (code === 0) {
        root.dockerPullStatus = "Pull complete";
        root.dockerPullPercent = 1;
        root.dockerPullResult = "Updated image: " + image;
      } else {
        root.dockerPullStatus = "Pull failed (code " + code + ")";
        root.dockerPullResult = "Pull failed for " + image + " (code " + code + ")";
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
      var out = HubModel.trimText(dockerPruneProc.stdout.text || "");
      var err = HubModel.trimText(dockerPruneProc.stderr.text || "");
      if (code === 0) {
        if (out.length > 0) {
          var lines = out.split("\n").map(function(l){ return HubModel.trimText(l); }).filter(function(l){ return l.length > 0; });
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

  function pruneStoppedContainers() {
    if (dockerPruneBusy || dockerBusy)
      return;
    dockerPruneBusy = true;
    dockerPruneProc.command = HubModel.dockerPruneCommand();
    dockerPruneProc.running = true;
    lastActionMessage = "Pruning stopped containers…";
  }

  // --- Processes / views: Games ---
  Process {
    id: steamPgrepProc
    command: HubModel.pgrepExactCommand("steam")
    onExited: function(code) { root.steamRunning = (code === 0) }
  }
  Process {
    id: bnetPgrepProc
    command: ["pgrep", "-f", "Battle.net"]
    onExited: function(code) { root.bnetRunning = (code === 0) }
  }
  Process {
    id: steamManifestProc
    stdout: StdioCollector { onStreamFinished: root.steamGameCount = HubModel.parseManifestCount(text) }
    stderr: StdioCollector {}
  }
  Process {
    id: bnetGameCountProc
    stdout: StdioCollector { onStreamFinished: root.bnetGameCount = HubModel.parseBattlenetGameCount(text) }
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
      var paths = HubModel.parseLibraryPathsFromVdf(text());
      var dirs = [];
      for (var i = 0; i < paths.length; i++) {
        var p = HubModel.trimText(paths[i]);
        if (p.length > 0)
          dirs.push(p + "/steamapps");
      }
      if (dirs.length === 0) {
        var steamRoot = HubModel.steamRootPath(root.homeDir);
        dirs = [steamRoot + "/steamapps", "/mnt/games/SteamLibrary/steamapps"];
      }
      steamManifestProc.running = false;
      steamManifestProc.command = HubModel.steamManifestCountCommandForDirs(dirs);
      steamManifestProc.running = true;
      root.steamNote = "Steam libraries detected: " + dirs.length + " (filtered installed games across libraries).";
    }
    onLoadFailed: {
      root.steamNote = "Counting installed games from default/common libraries.";
    }
  }

  // --- Processes: Game mount ---
  Process {
    id: findmntProc
    command: HubModel.findmntCommand(root.gameMount)
    stdout: StdioCollector {
      onStreamFinished: {
        var info = HubModel.parseFindmnt(text);
        root.gameMountPresent = !!info;
      }
    }
    onExited: function(code) {
      if (code !== 0) root.gameMountPresent = false;
    }
  }
  Process {
    id: dfProc
    command: HubModel.dfBytesCommand(root.gameMount)
    stdout: StdioCollector {
      onStreamFinished: {
        var info = HubModel.parseDfBytes(text);
        if (info) {
          root.gameMountPresent = true;
          root.gameMountUsedBytes = info.usedBytes;
          root.gameMountAvailBytes = info.availBytes;
          root.gameMountTotalBytes = info.totalBytes;
          root.gameMountUseRatio = info.totalBytes > 0 ? Math.max(0, Math.min(1, info.usedBytes / info.totalBytes)) : 0;
          root.gameMountUsePercentText = HubModel.trimText(info.usePercent);
          root.gameMountSummary = HubModel.humanBytes(info.usedBytes) + " used / "
            + HubModel.humanBytes(info.availBytes) + " free / "
            + HubModel.humanBytes(info.totalBytes) + " total (" + info.usePercent + ")";
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: if (HubModel.trimText(text).length > 0) root.gameMountError = HubModel.trimText(text)
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
  }

  Process {
    id: manifestReadProc
    command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "sh", Quickshell.env("HOME") + "/.config/omarchy/plugins/elena.vember-server-hub/manifest.json"]
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = HubModel.trimText(text);
        if (raw.length === 0)
          return;
        try {
          var obj = JSON.parse(raw);
          if (obj && obj.version) root.pluginVersion = String(obj.version);
          if (obj && obj.build !== undefined && obj.build !== null) root.pluginBuild = Number(obj.build) || 1;
        } catch (e) {}
      }
    }
    stderr: StdioCollector {}
  }

  Process {
    id: configReadProc
    command: ["sh", "-c", "if [ -f \"$1\" ]; then cat \"$1\"; fi", "sh", root.configPath]
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = HubModel.trimText(text);
        if (raw.length === 0) {
          root.configReady = false;
          root.serverName = "";
          root.serverRole = "";
          root.openWizard(root.defaultServerName());
          return;
        }
        try {
          var obj = JSON.parse(raw);
          var name = HubModel.trimText(obj && obj.serverName ? obj.serverName : "");
          var role = HubModel.trimText(obj && obj.serverRole ? obj.serverRole : "");
          var editor = HubModel.trimText(obj && obj.preferredEditor ? obj.preferredEditor : "");
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
        var err = HubModel.trimText(text);
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
    command: HubModel.devToolCheckCommand()
    stdout: StdioCollector {
      onStreamFinished: {
        root.devTools = HubModel.parseDevToolChecks(text);
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
        var err = HubModel.trimText(text);
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
    command: HubModel.devReposScanCommand(root.homeDir)
    stdout: StdioCollector {
      onStreamFinished: {
        root.devRepos = HubModel.parseDevRepos(text);
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
    command: HubModel.codeServerPsCommand()
    stdout: StdioCollector {
      onStreamFinished: {
        var info = HubModel.parseCodeServerStatus(text);
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
      if (HubModel.trimText(root.devInstallStatus).length === 0 || root.devToolsOnlyRefresh)
        root.devStatus = base + " VS Code Server: " + (root.codeServerPresent ? root.codeServerState : "not set up") + ".";
      else
        root.devStatus = root.devInstallStatus + " VS Code Server: " + (root.codeServerPresent ? root.codeServerState : "not set up") + ".";
      root.codeServerBusy = false;
    }
  }
  Process {
    id: devInstallProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: devInstallSilentProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.devInstallBusy = false;
      var label = HubModel.devToolLabel(root.devInstallToolId);
      var err = HubModel.trimText(devInstallSilentProc.stderr.text || "");
      var out = HubModel.trimText(devInstallSilentProc.stdout.text || "");
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
    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
  Process {
    id: codeServerActionProc
    property string actionName: ""
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      root.codeServerBusy = false;
      if (actionName === "setup") {
        root.devStatus = "VS Code Server setup terminal opened (review password/URL there). Refreshing status…";
      } else if (code === 0) {
        root.devStatus = "VS Code Server " + actionName + " succeeded.";
      } else {
        root.devStatus = "VS Code Server " + actionName + " failed (code " + code + ").";
      }
      root.refreshCodeServer();
      root.refreshDocker();
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/plugins/elena.vember-server-hub/manifest.json"
    printErrors: false
    watchChanges: true
    onFileChanged: root.scheduleHotReload()
  }
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/plugins/elena.vember-server-hub/Panel.qml"
    printErrors: false
    watchChanges: true
    onFileChanged: root.scheduleHotReload()
  }
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/plugins/elena.vember-server-hub/HubPanel.qml"
    printErrors: false
    watchChanges: true
    onFileChanged: root.scheduleHotReload()
  }
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/plugins/elena.vember-server-hub/model/HubModel.js"
    printErrors: false
    watchChanges: true
    onFileChanged: root.scheduleHotReload()
  }

  HubPanel {
    hub: root
  }
}
