import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "model/DevTools.mjs" as DevTools
import "model/Shell.mjs" as Shell
import "ui/tabs"

PanelWindow {
  id: panel
  required property var hub

  property string currentTab: "overview"
  property bool confirmPrune: false
  property bool confirmRemoveSshKey: false
  property bool confirmRemoveCodeServer: false
  property bool codeServerSetupOpen: false
  property string codeServerSetupPassword: ""
  property string codeServerSetupPort: "8443"
  property bool settingsMenuOpen: false
  property bool arrangeTabsOpen: false
  property var arrangeTabOrderDraft: []
  property bool updateDialogOpen: false
  property bool updateInProgress: false
  property real updateProgress: 0
  property string updateStatusText: ""
  property var toastItems: []
  property int toastSeq: 0
  property bool isFullscreen: false
  property string devSubTab: "workspace"
  property string accessSubTab: "tailnet"
  property string gamesSubTab: "launchers"
  property string containersSubTab: "containers"
  property string overviewSubTab: "overview"


  function toggleFullscreen() {
    panel.isFullscreen = !panel.isFullscreen;
  }

  function removeToastById(id) {
    var items = (panel.toastItems || []).slice(0);
    var out = [];
    for (var i = 0; i < items.length; i++) {
      if (items[i] && items[i].id !== id) out.push(items[i]);
    }
    panel.toastItems = out;
  }

  function showToastIfNeeded(msg) {
    var text = Shell.trim(msg);
    if (text.length === 0) return;
    if (text.indexOf("Docker ") === 0 || text.indexOf("Prun") === 0) return;

    var items = (panel.toastItems || []).slice(0);
    if (items.length > 0 && items[items.length - 1].text === text) return;

    panel.toastSeq = panel.toastSeq + 1;
    items.push({ id: panel.toastSeq, text: text });
    if (items.length > 4) items = items.slice(items.length - 4);
    panel.toastItems = items;
  }

  Connections {
    target: hub
    function onLastActionMessageChanged() {
      panel.showToastIfNeeded(hub.lastActionMessage);
    }
  }

  function tabDef(id) {
    if (id === "overview") return { id: "overview", label: "Overview", icon: "󰕮" };
    if (id === "access") return { id: "access", label: "Access", icon: "󰖂" };
    if (id === "containers") return { id: "containers", label: "Containers", icon: "󰡨" };
    if (id === "games") return { id: "games", label: "Gaming", icon: "󰊴" };
    if (id === "dev") return { id: "dev", label: "Dev", icon: "󰅨" };
    return { id: id, label: id, icon: "󰘔" };
  }

  function orderedTabs() {
    var order = (hub && hub.tabOrder && hub.tabOrder.length > 0) ? hub.tabOrder : ["overview", "access", "containers", "games", "dev"];
    var out = [];
    for (var i = 0; i < order.length; i++) out.push(tabDef(order[i]));
    return out;
  }

  function openArrangeTabsDialog() {
    var order = (hub && hub.tabOrder && hub.tabOrder.length > 0) ? hub.tabOrder : ["overview", "access", "containers", "games", "dev"];
    panel.arrangeTabOrderDraft = order.slice(0);
    panel.settingsMenuOpen = false;
    panel.arrangeTabsOpen = true;
  }

  function moveArrangeTabDraft(index, delta) {
    var next = (panel.arrangeTabOrderDraft || []).slice(0);
    var j = index + delta;
    if (index < 0 || j < 0 || index >= next.length || j >= next.length) return;
    var tmp = next[index];
    next[index] = next[j];
    next[j] = tmp;
    panel.arrangeTabOrderDraft = next;
  }

  function saveArrangeTabs() {
    hub.tabOrder = (panel.arrangeTabOrderDraft || []).slice(0);
    if (typeof hub.writeHubConfig === "function") hub.writeHubConfig(false);
    panel.arrangeTabsOpen = false;
  }

  visible: hub.opened
  screen: hub.targetScreen ? hub.targetScreen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
  color: "transparent"
  WlrLayershell.namespace: "elena-vember-server-hub"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: hub.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  function softText(alpha) {
    return Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, alpha)
  }

  function accentSoft(alpha) {
    return Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, alpha)
  }

  function stateColor(active, okText) {
    if (active) return accentSoft(0.22)
    return softText(0.08)
  }

  function dockerStateTone(state) {
    var s = Shell.trim(state).toLowerCase()
    if (s === "running") return "#22c55e"
    if (s === "restarting" || s === "paused" || s === "created") return "#eab308"
    if (s === "exited" || s === "dead" || s === "removing") return "#ef4444"
    return softText(0.5)
  }

  function dockerStateBg(state) {
    var s = Shell.trim(state).toLowerCase()
    if (s === "running") return Qt.rgba(0.13, 0.77, 0.37, 0.18)
    if (s === "restarting" || s === "paused" || s === "created") return Qt.rgba(0.92, 0.70, 0.03, 0.18)
    if (s === "exited" || s === "dead" || s === "removing") return Qt.rgba(0.94, 0.27, 0.27, 0.18)
    return softText(0.08)
  }

  function storageUseColor(ratio) {
    var r = Number(ratio || 0)
    if (r >= 0.90) return "#ef4444"
    if (r >= 0.75) return "#eab308"
    return "#22c55e"
  }

  function runningDockerCount() {
    var n = 0
    for (var i = 0; i < hub.dockerContainers.length; i++) {
      if (hub.dockerContainers[i] && hub.dockerContainers[i].running) n++
    }
    return n
  }

  function onlinePeerCount() {
    var n = 0
    for (var i = 0; i < hub.tailscalePeers.length; i++) {
      if (hub.tailscalePeers[i] && hub.tailscalePeers[i].online) n++
    }
    return n
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.38)
    MouseArea {
      anchors.fill: parent
      onClicked: hub.requestClose()
    }
  }

  Rectangle {
    id: card
    readonly property int margin: panel.isFullscreen ? 0 : Style.gapsOut
    anchors.centerIn: panel.isFullscreen ? undefined : parent
    anchors.fill: panel.isFullscreen ? parent : undefined
    width: panel.isFullscreen ? undefined : Math.min(panel.width - margin * 2, 1040)
    height: panel.isFullscreen ? undefined : Math.min(panel.height - margin * 2, 860)
    radius: panel.isFullscreen ? 0 : Style.cornerRadius
    color: Color.menu.background
    border.color: panel.isFullscreen ? "transparent" : softText(0.14)
    border.width: panel.isFullscreen ? 0 : 1

    MouseArea { anchors.fill: parent; onClicked: {} }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.md

      // Header bar
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + 12
        radius: 12
        color: softText(0.04)
        border.color: softText(0.08)
        border.width: 1

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: 8
          spacing: Style.spacing.sm

          // Left: title + icon
          RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8
            Text {
              textFormat: Text.PlainText
              text: "󰒋"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.iconLarge
            }
            Column {
              spacing: 0
              Text {
                textFormat: Text.PlainText
                text: Shell.trim(hub.serverName).length > 0 ? hub.serverName : "Vember Server Hub"
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                visible: Shell.trim(hub.serverName).length > 0 && Shell.trim(hub.serverRole).length > 0
                textFormat: Text.PlainText
                text: hub.serverRole
                color: softText(0.65)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          Item { Layout.fillWidth: true }

          // Middle: nav items
          Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Style.spacing.sm
            Repeater {
              model: panel.orderedTabs()
              delegate: Button {
                required property var modelData
                iconText: modelData.icon
                text: modelData.label
                active: panel.currentTab === modelData.id
                onClicked: panel.currentTab = modelData.id
              }
            }
          }

          Item { Layout.fillWidth: true }

          // Right: update-ready + reload + fullscreen + settings + exit
          RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            Button {
              visible: hub.updateAvailable
              iconText: "󰚰"
              text: "Update ready"
              tooltipText: "A new build is available on GitHub"
              active: true
              onClicked: {
                panel.settingsMenuOpen = false;
                panel.updateStatusText = hub.pluginUpdateStatus || "Ready to update from GitHub.";
                panel.updateProgress = hub.pluginUpdateProgress;
                panel.updateInProgress = hub.pluginUpdateBusy;
                panel.updateDialogOpen = true;
              }
            }
            Button {
              iconText: "󰑓"
              text: "Reload"
              tooltipText: "Reload hub (restart shell and reopen)"
              active: true
              onClicked: hub.hotReloadHub()
            }
            Button {
              iconText: panel.isFullscreen ? "󰊓" : "󰊔"
              tooltipText: panel.isFullscreen ? "Exit fullscreen" : "Fullscreen"
              active: panel.isFullscreen
              onClicked: panel.toggleFullscreen()
            }
            Button {
              id: settingsMenuButton
              iconText: "󰍜"
              tooltipText: "Settings"
              active: panel.settingsMenuOpen
              onClicked: panel.settingsMenuOpen = !panel.settingsMenuOpen
            }
            Button {
              iconText: "󰅖"
              tooltipText: "Exit"
              onClicked: hub.requestClose()
            }
          }
        }
      }

      Item { Layout.fillWidth: true; Layout.preferredHeight: 0; visible: false }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentCol
          width: parent.width
          spacing: Style.spacing.md

          // OVERVIEW TAB
          OverviewTab { panel: panel }

          // ACCESS TAB
          AccessTab { panel: panel }

          // CONTAINERS TAB
          ContainersTab { panel: panel }

          // GAMES TAB
          GamesTab { panel: panel }

          // DEV TAB
          DevTab { panel: panel }

        }
      }

      // Footer
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: footerRow.implicitHeight + 10
        radius: 10
        color: softText(0.03)
        border.color: softText(0.06)
        border.width: 1

        RowLayout {
          id: footerRow
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          anchors.topMargin: 5
          anchors.bottomMargin: 5
          spacing: 8

          Text {
            textFormat: Text.PlainText
            text: "Vember Server Hub v" + (hub.pluginVersion || "0.1.0")
            color: softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: "•"
            color: softText(0.45)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            textFormat: Text.PlainText
            text: "Built by elenanight"
            color: softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            textFormat: Text.PlainText
            text: "build " + (hub.pluginBuild || 1) + " • © 2026"
            color: softText(0.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    // Code Server setup dialog
    Rectangle {
      visible: panel.codeServerSetupOpen
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 110

      MouseArea {
        anchors.fill: parent
        onClicked: panel.codeServerSetupOpen = false
      }

      Rectangle {
        id: codeServerSetupDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 500)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: codeServerSetupCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: codeServerSetupCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰨞"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { textFormat: Text.PlainText; text: "Set up VS Code Server"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: "Create the code-server Docker container, set your sign-in password/port, provision Python, uv, GitHub CLI (gh), and Python extensions, and prepare a default Python workspace in ~/Projects."; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Password"
            color: Color.menu.text
            font.family: Style.font.family
            font.bold: true
          }
          Rectangle {
            width: parent.width
            radius: 8
            color: softText(0.03)
            border.color: accentSoft(0.2)
            border.width: 1
            implicitHeight: 40
            TextInput {
              id: codeServerPasswordInput
              anchors.fill: parent
              anchors.margins: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              selectByMouse: true
              clip: true
              echoMode: TextInput.Password
              text: panel.codeServerSetupPassword
              onTextChanged: panel.codeServerSetupPassword = text
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Host port"
            color: Color.menu.text
            font.family: Style.font.family
            font.bold: true
          }
          Rectangle {
            width: parent.width
            radius: 8
            color: softText(0.03)
            border.color: accentSoft(0.2)
            border.width: 1
            implicitHeight: 40
            TextInput {
              id: codeServerPortInput
              anchors.fill: parent
              anchors.margins: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              selectByMouse: true
              clip: true
              inputMethodHints: Qt.ImhDigitsOnly
              text: panel.codeServerSetupPort
              onTextChanged: panel.codeServerSetupPort = text
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Pick a free host port. If the container already exists, Uninstall it first to apply new mounts, port, password, or provisioning changes."
            color: softText(0.72)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: "Cancel"
              onClicked: panel.codeServerSetupOpen = false
            }
            Button {
              iconText: "󰏔"
              text: "Set up"
              active: true
              enabled: Shell.trim(panel.codeServerSetupPassword).length > 0 && !hub.codeServerBusy
              onClicked: {
                panel.codeServerSetupOpen = false;
                hub.setupCodeServerTerminal(panel.codeServerSetupPassword, panel.codeServerSetupPort);
                panel.codeServerSetupPassword = "";
              }
            }
          }
        }
      }
    }

    // Confirm prune popup
    Rectangle {
      visible: panel.confirmPrune
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 100

      MouseArea {
        anchors.fill: parent
        onClicked: panel.confirmPrune = false
      }

      Rectangle {
        id: pruneDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 460)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: pruneDialogCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: pruneDialogCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰃢"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            Text { textFormat: Text.PlainText; text: "Prune stopped containers?"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; Layout.fillWidth: true }
          }

          Text {
            textFormat: Text.PlainText
            text: "This will remove all stopped containers (docker container prune -f). Running containers are not affected. This cannot be undone."
            color: softText(0.85)
            font.family: Style.font.family
            wrapMode: Text.Wrap
            width: parent.width
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: "Cancel"
              onClicked: panel.confirmPrune = false
            }
            Button {
              iconText: "󰃢"
              text: hub.dockerPruneBusy ? "Pruning…" : "Prune"
              enabled: !hub.dockerPruneBusy
              onClicked: {
                panel.confirmPrune = false;
                hub.pruneStoppedContainers();
              }
            }
          }
        }
      }
    }

    // Confirm remove SSH key popup
    Rectangle {
      visible: panel.confirmRemoveSshKey
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 100

      MouseArea {
        anchors.fill: parent
        onClicked: panel.confirmRemoveSshKey = false
      }

      Rectangle {
        id: removeKeyDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 480)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: removeKeyDialogCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: removeKeyDialogCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          readonly property var selectedKey: (hub.sshSelectedKeyIndex >= 0 && hub.sshSelectedKeyIndex < (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)) ? hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] : null

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰆴"; color: "#ef4444"; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            Text { textFormat: Text.PlainText; text: "Remove authorized key?"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; Layout.fillWidth: true }
          }

          Text {
            textFormat: Text.PlainText
            text: "This will remove the selected key from ~/.ssh/authorized_keys. This cannot be undone."
            color: softText(0.85)
            font.family: Style.font.family
            wrapMode: Text.Wrap
            width: parent.width
          }

          Text {
            visible: !!removeKeyDialogCol.selectedKey
            textFormat: Text.PlainText
            text: removeKeyDialogCol.selectedKey ? ((Shell.trim(removeKeyDialogCol.selectedKey.comment || "").length > 0 ? removeKeyDialogCol.selectedKey.comment : (removeKeyDialogCol.selectedKey.type || "Key")) + " • " + (removeKeyDialogCol.selectedKey.keyPreview || "")) : ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: "Cancel"
              onClicked: panel.confirmRemoveSshKey = false
            }
            Button {
              iconText: "󰆴"
              text: "Remove"
              enabled: hub.sshSelectedKeyIndex >= 0 && hub.sshSelectedKeyIndex < (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
              onClicked: {
                panel.confirmRemoveSshKey = false;
                hub.removeSelectedAuthorizedKey();
              }
            }
          }
        }
      }
    }

    // Confirm remove VS Code Server container popup
    Rectangle {
      visible: panel.confirmRemoveCodeServer
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 100

      MouseArea {
        anchors.fill: parent
        onClicked: panel.confirmRemoveCodeServer = false
      }

      Rectangle {
        id: removeCodeServerDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 480)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: removeCodeServerCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: removeCodeServerCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰆴"; color: "#ef4444"; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            Text { textFormat: Text.PlainText; text: "Uninstall VS Code Server?"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; Layout.fillWidth: true }
          }

          Text {
            textFormat: Text.PlainText
            text: "This will remove the `vember-code-server` Docker container (forced if running). Local config/data in ~/.config/vember-code-server is kept."
            color: softText(0.85)
            font.family: Style.font.family
            wrapMode: Text.Wrap
            width: parent.width
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: "Cancel"
              onClicked: panel.confirmRemoveCodeServer = false
            }
            Button {
              iconText: "󰆴"
              text: "Uninstall"
              enabled: !hub.codeServerBusy
              onClicked: {
                panel.confirmRemoveCodeServer = false;
                hub.uninstallCodeServer();
              }
            }
          }
        }
      }
    }

    // Settings menu
    Rectangle {
      visible: panel.settingsMenuOpen
      anchors.fill: parent
      color: "transparent"
      z: 150
      MouseArea {
        anchors.fill: parent
        onClicked: panel.settingsMenuOpen = false
      }
      Rectangle {
        id: settingsMenuCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 64
        anchors.rightMargin: 16
        width: 240
        radius: 12
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: settingsMenuCol.implicitHeight + 12

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: settingsMenuCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 6
          spacing: 2

          Button {
            width: parent.width
            iconText: "󰁁"
            text: "Arrange tabs"
            tooltipText: "Reorder navigation tabs"
            onClicked: panel.openArrangeTabsDialog()
          }
          Button {
            width: parent.width
            iconText: "󰒋"
            text: "Server settings"
            tooltipText: "Rename server or change role"
            onClicked: {
              panel.settingsMenuOpen = false;
              hub.openWizard(hub.serverName || hub.defaultServerName());
            }
          }
          Button {
            width: parent.width
            iconText: "󰚰"
            text: hub.updateAvailable ? "Update ready" : "Check for updates"
            tooltipText: hub.updateAvailable ? "A new build is available on GitHub" : "Check GitHub for a newer build"
            onClicked: {
              panel.settingsMenuOpen = false;
              if (hub.updateAvailable) {
                panel.updateStatusText = hub.pluginUpdateStatus || "Ready to update from GitHub.";
                panel.updateProgress = hub.pluginUpdateProgress;
                panel.updateInProgress = hub.pluginUpdateBusy;
                panel.updateDialogOpen = true;
              } else {
                panel.updateStatusText = "Checking for updates…";
                panel.updateProgress = 0;
                panel.updateInProgress = false;
                hub.pluginUpdateProgress = 0;
                hub.pluginUpdateError = "";
                hub.pluginUpdatePun = "";
                hub.pluginUpdateStatus = "Checking for updates…";
                panel.updateDialogOpen = true;
                hub.checkPluginUpdate(true);
              }
            }
          }
        }
      }
    }

    // Arrange tabs dialog
    Rectangle {
      visible: panel.arrangeTabsOpen
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 155

      MouseArea {
        anchors.fill: parent
        onClicked: panel.arrangeTabsOpen = false
      }

      Rectangle {
        id: arrangeTabsDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 460)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: arrangeTabsCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: arrangeTabsCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰁁"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { textFormat: Text.PlainText; text: "Arrange tabs"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: "Move tabs up or down, then save the order."; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
          }

          Column {
            width: parent.width
            spacing: 6
            Repeater {
              model: panel.arrangeTabOrderDraft || []
              delegate: Rectangle {
                required property var modelData
                required property int index
                width: parent ? parent.width : 0
                radius: 8
                color: softText(0.04)
                border.color: softText(0.08)
                border.width: 1
                implicitHeight: arrangeRow.implicitHeight + 12
                RowLayout {
                  id: arrangeRow
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 8
                  spacing: 8
                  Text {
                    textFormat: Text.PlainText
                    text: panel.tabDef(modelData).icon
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: panel.tabDef(modelData).label
                    color: Color.menu.text
                    font.family: Style.font.family
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                  Button {
                    iconText: "󰅃"
                    tooltipText: "Move up"
                    enabled: index > 0
                    onClicked: panel.moveArrangeTabDraft(index, -1)
                  }
                  Button {
                    iconText: "󰅀"
                    tooltipText: "Move down"
                    enabled: index < ((panel.arrangeTabOrderDraft || []).length - 1)
                    onClicked: panel.moveArrangeTabDraft(index, 1)
                  }
                }
              }
            }
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: "Cancel"
              onClicked: panel.arrangeTabsOpen = false
            }
            Button {
              iconText: "󰄬"
              text: "Save"
              active: true
              onClicked: panel.saveArrangeTabs()
            }
          }
        }
      }
    }

    // Update dialog (GitHub build update)
    Rectangle {
      id: updateDialogRoot
      visible: panel.updateDialogOpen
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 160

      property bool busy: hub.pluginUpdateBusy || hub.updateCheckBusy
      property real progress: hub.pluginUpdateBusy ? hub.pluginUpdateProgress : (hub.updateCheckBusy ? 0 : hub.pluginUpdateProgress)
      property bool done: !hub.pluginUpdateBusy && !hub.updateCheckBusy && hub.pluginUpdateProgress >= 1 && Shell.trim(hub.pluginUpdateError).length === 0

      MouseArea { anchors.fill: parent; onClicked: { if (!updateDialogRoot.busy) panel.updateDialogOpen = false; } }

      Rectangle {
        id: updateDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 520)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: updateDialogCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: updateDialogCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14
          spacing: 12

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰚰"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { textFormat: Text.PlainText; text: hub.updateAvailable ? "Update ready" : "Plugin update"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text {
                textFormat: Text.PlainText
                text: hub.updateAvailable ? ("New commits available on GitHub" + (hub.pluginUpdateRemoteCommits > 0 ? (" (" + hub.pluginUpdateRemoteCommits + ")") : "") + ".") : (hub.updateCheckBusy ? "Checking GitHub for updates…" : "Check GitHub for a newer build.")
                color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true
              }
            }
          }

          Text {
            visible: Shell.trim(hub.pluginUpdatePun).length > 0 && (hub.pluginUpdateBusy || updateDialogRoot.done)
            textFormat: Text.PlainText
            text: hub.pluginUpdatePun
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.italic: true
            wrapMode: Text.Wrap
            width: parent.width
          }

          Text {
            visible: Shell.trim(hub.pluginUpdateStatus).length > 0 || Shell.trim(panel.updateStatusText).length > 0
            textFormat: Text.PlainText
            text: Shell.trim(hub.pluginUpdateStatus).length > 0 ? hub.pluginUpdateStatus : panel.updateStatusText
            color: Shell.trim(hub.pluginUpdateError).length > 0 ? "#ef4444" : softText(0.85)
            font.family: Style.font.family
            wrapMode: Text.Wrap
            width: parent.width
          }

          Rectangle {
            visible: updateDialogRoot.busy || hub.pluginUpdateProgress > 0 || updateDialogRoot.done
            width: parent.width
            height: 10
            radius: 5
            color: softText(0.12)
            clip: true
            Rectangle {
              id: updateProgressFill
              height: parent.height
              radius: 5
              color: Shell.trim(hub.pluginUpdateError).length > 0 ? "#ef4444" : Color.accent
              width: updateDialogRoot.progress > 0 ? (parent.width * Math.max(0, Math.min(1, updateDialogRoot.progress))) : (updateDialogRoot.busy ? parent.width * 0.35 : 0)
              x: (updateDialogRoot.busy && updateDialogRoot.progress <= 0) ? -width : 0
              Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
              SequentialAnimation on x {
                running: updateDialogRoot.busy && updateDialogRoot.progress <= 0 && panel.updateDialogOpen
                loops: Animation.Infinite
                NumberAnimation { from: -updateProgressFill.width; to: updateDialog.width; duration: Style.duration(1200); easing.type: Easing.InOutQuad }
              }
            }
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: updateDialogRoot.busy ? "Updating…" : "Close"
              enabled: !updateDialogRoot.busy
              onClicked: panel.updateDialogOpen = false
            }
            Button {
              visible: updateDialogRoot.done
              iconText: "󰑓"
              text: "Reload"
              active: true
              onClicked: {
                panel.updateDialogOpen = false;
                hub.hotReloadHub();
              }
            }
            Button {
              visible: hub.updateAvailable && !updateDialogRoot.done
              iconText: "󰚰"
              text: updateDialogRoot.busy ? "Updating…" : "Update now"
              active: true
              enabled: !updateDialogRoot.busy
              onClicked: {
                hub.startPluginUpdate();
              }
            }
            Button {
              visible: !hub.updateAvailable && !updateDialogRoot.busy && !updateDialogRoot.done
              iconText: "󰑐"
              text: "Check again"
              onClicked: {
                hub.pluginUpdateStatus = "Checking for updates…";
                hub.pluginUpdateProgress = 0;
                hub.pluginUpdateError = "";
                hub.pluginUpdatePun = "";
                hub.checkPluginUpdate(true);
              }
            }
          }
        }
      }
    }

    // Toast notifications (stacked, bottom-right)
    Column {
      id: toastStack
      z: 170
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: 16
      anchors.bottomMargin: 16
      spacing: 8
      width: Math.min(360, parent.width - 32)

      Repeater {
        model: panel.toastItems || []
        delegate: Rectangle {
          id: toastItem
          required property var modelData
          required property int index
          width: toastStack.width
          radius: 10
          color: Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.97)
          border.color: accentSoft(0.35)
          border.width: 1
          implicitHeight: toastItemLabel.implicitHeight + 18
          opacity: 0

          transform: Translate {
            id: toastSlide
            y: 14
          }

          Component.onCompleted: {
            opacity = 1;
            toastSlide.y = 0;
          }

          Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

          Timer {
            interval: 4200
            repeat: false
            running: true
            onTriggered: panel.removeToastById(toastItem.modelData.id)
          }

          Text {
            id: toastItemLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 10
            textFormat: Text.PlainText
            text: toastItem.modelData.text || ""
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.removeToastById(toastItem.modelData.id)
          }
        }
      }
    }

    // First-use wizard: server name
    Rectangle {
      visible: hub.wizardOpen
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 120

      MouseArea { anchors.fill: parent; onClicked: {} }

      Rectangle {
        id: wizardDialog
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 520)
        radius: 14
        color: Color.menu.background
        border.color: accentSoft(0.25)
        border.width: 1
        implicitHeight: wizardCol.implicitHeight + 28

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
          id: wizardCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 16
          spacing: 12

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰒋"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { textFormat: Text.PlainText; text: "Welcome to Vember Server Hub"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: "Name this server to personalize your hub."; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Server name"
            color: Color.menu.text
            font.family: Style.font.family
            font.bold: true
          }
          Rectangle {
            width: parent.width
            radius: 8
            color: softText(0.03)
            border.color: accentSoft(0.2)
            border.width: 1
            implicitHeight: 40
            TextInput {
              id: serverNameInput
              anchors.fill: parent
              anchors.margins: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              selectByMouse: true
              clip: true
              text: hub.serverNameDraft
              onTextChanged: hub.serverNameDraft = text
            }
          }

          Text {
            textFormat: Text.PlainText
            text: "Server role (optional)"
            color: Color.menu.text
            font.family: Style.font.family
            font.bold: true
          }
          Rectangle {
            width: parent.width
            radius: 8
            color: softText(0.03)
            border.color: accentSoft(0.2)
            border.width: 1
            implicitHeight: 40
            TextInput {
              id: serverRoleInput
              anchors.fill: parent
              anchors.margins: 10
              verticalAlignment: TextInput.AlignVCenter
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              selectByMouse: true
              clip: true
              text: hub.serverRoleDraft
              onTextChanged: hub.serverRoleDraft = text
            }
          }
          Text {
            textFormat: Text.PlainText
            text: "Examples: NAS, file server, gaming server, coding/dev server, media server, or mixed. Defaults to hostname for the name (" + hub.defaultServerName() + ")."
            color: softText(0.72)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              visible: hub.configReady
              text: "Cancel"
              onClicked: {
                hub.serverNameDraft = Shell.trim(hub.serverName).length > 0 ? hub.serverName : hub.defaultServerName();
                hub.serverRoleDraft = hub.serverRole || "";
                hub.wizardOpen = false;
              }
            }
            Button {
              text: "Use hostname"
              onClicked: {
                hub.serverNameDraft = hub.defaultServerName();
                serverNameInput.text = hub.serverNameDraft;
              }
            }
            Button {
              iconText: "󰄬"
              text: "Save"
              active: true
              onClicked: hub.saveServerName(hub.serverNameDraft)
            }
          }
        }
      }
    }
  }
}
