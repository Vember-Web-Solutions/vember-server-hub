import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "model/HubModel.js" as HubModel

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
    var text = HubModel.trimText(msg);
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
    var s = HubModel.trimText(state).toLowerCase()
    if (s === "running") return "#22c55e"
    if (s === "restarting" || s === "paused" || s === "created") return "#eab308"
    if (s === "exited" || s === "dead" || s === "removing") return "#ef4444"
    return softText(0.5)
  }

  function dockerStateBg(state) {
    var s = HubModel.trimText(state).toLowerCase()
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
                text: HubModel.trimText(hub.serverName).length > 0 ? hub.serverName : "Vember Server Hub"
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                visible: HubModel.trimText(hub.serverName).length > 0 && HubModel.trimText(hub.serverRole).length > 0
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
          Column {
            visible: panel.currentTab === "overview"
            width: parent.width
            spacing: Style.spacing.md

            Row {
              spacing: 8
              Button {
                iconText: "󰋜"
                text: "Overview"
                active: panel.overviewSubTab === "overview"
                onClicked: panel.overviewSubTab = "overview"
              }
              Button {
                iconText: "󰚰"
                text: "Update"
                active: panel.overviewSubTab === "update"
                onClicked: panel.overviewSubTab = "update"
              }
            }

            Column {
              visible: panel.overviewSubTab === "overview"
              width: parent.width
              spacing: Style.spacing.lg

              // Hero / server summary
              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: accentSoft(0.08)
                border.color: accentSoft(0.20)
                border.width: 1
                implicitHeight: heroCol.implicitHeight + 28
                Column {
                  id: heroCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 14
                  spacing: 10

                  RowLayout {
                    width: parent.width
                    spacing: 14
                    Text {
                      Layout.alignment: Qt.AlignVCenter
                      textFormat: Text.PlainText
                      text: "󰒋"
                      color: Color.accent
                      font.family: Style.font.family
                      font.pixelSize: Math.round(Style.font.iconLarge * 1.5)
                    }
                    Text {
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      textFormat: Text.PlainText
                      text: hub.defaultServerName()
                      color: Color.menu.text
                      font.family: Style.font.family
                      font.pixelSize: Math.round(Style.font.heading * 1.4)
                      font.bold: true
                      elide: Text.ElideRight
                      verticalAlignment: Text.AlignVCenter
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "Use the tabs to check access, manage containers, open repositories, and monitor gaming and storage on this server."
                    color: softText(0.78)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                    width: parent.width
                  }

                  Flow {
                    width: parent.width
                    spacing: 8
                    Rectangle {
                      radius: 10
                      color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : softText(0.1)
                      border.color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
                      border.width: hub.tailscaleActive === "active" ? 1 : 0
                      implicitWidth: heroTsChip.implicitWidth + 14
                      implicitHeight: heroTsChip.implicitHeight + 8
                      Text {
                        id: heroTsChip
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "Tailnet: " + hub.tailscaleActive
                        color: hub.tailscaleActive === "active" ? "#22c55e" : Color.menu.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: hub.tailscaleActive === "active"
                      }
                    }
                    Rectangle {
                      radius: 10
                      color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : softText(0.1)
                      border.color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
                      border.width: hub.sshActive === "active" ? 1 : 0
                      implicitWidth: heroSshChip.implicitWidth + 14
                      implicitHeight: heroSshChip.implicitHeight + 8
                      Text {
                        id: heroSshChip
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: "SSH: " + hub.sshActive
                        color: hub.sshActive === "active" ? "#22c55e" : Color.menu.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: hub.sshActive === "active"
                      }
                    }
                  }
                }
              }

              Column {
                width: parent.width
                spacing: Style.spacing.sm

                Text {
                  textFormat: Text.PlainText
                  text: "At a glance"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.heading
                  font.bold: true
                }

                Text {
                  textFormat: Text.PlainText
                  text: "Open a card for details and controls."
                  color: softText(0.72)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              Flow {
                width: parent.width
                spacing: 14

                // Access glance
                Rectangle {
                  width: 320
                  radius: 14
                  color: softText(0.045)
                  border.color: hub.tailscaleActive === "active" ? accentSoft(0.35) : softText(0.10)
                  border.width: 1
                  implicitHeight: glanceTs.implicitHeight + 24
                  MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "access" }
                  Column {
                    id: glanceTs
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14; spacing: 10
                    RowLayout {
                      width: parent.width; spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰖂"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Access"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text {
                          textFormat: Text.PlainText
                          text: HubModel.trimText(hub.tailscaleTailnetName).length > 0 ? hub.tailscaleTailnetName : (HubModel.trimText(hub.serverName).length > 0 ? hub.serverName : hub.defaultServerName())
                          color: softText(0.78)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }
                      Rectangle {
                        radius: 10
                        color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : softText(0.1)
                        border.color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
                        border.width: hub.tailscaleActive === "active" ? 1 : 0
                        implicitWidth: glanceTsBadge.implicitWidth + 14
                        implicitHeight: glanceTsBadge.implicitHeight + 8
                        Text {
                          id: glanceTsBadge
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: hub.tailscaleActive
                          color: hub.tailscaleActive === "active" ? "#22c55e" : Color.menu.text
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: hub.tailscaleActive === "active"
                        }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Column {
                      width: parent.width
                      spacing: 6
                      Text { textFormat: Text.PlainText; text: "Peers: " + panel.onlinePeerCount() + " online / " + hub.tailscalePeers.length + " total"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                      Text { visible: HubModel.trimText(hub.tailscaleIp).length > 0; textFormat: Text.PlainText; text: "Tailnet IP: " + hub.tailscaleIp; color: softText(0.82); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                      Text { textFormat: Text.PlainText; text: "SSH " + hub.sshActive + " • tailscaled " + hub.tailscaleEnabled; color: softText(0.72); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }

                    Text { textFormat: Text.PlainText; text: "Open Access tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  }
                }

                // Containers glance
                Rectangle {
                  width: 320
                  radius: 14
                  color: softText(0.045)
                  border.color: HubModel.trimText(hub.dockerError).length > 0 ? Qt.rgba(0.94, 0.27, 0.27, 0.35) : accentSoft(0.18)
                  border.width: 1
                  implicitHeight: glanceDk.implicitHeight + 24
                  MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "containers" }
                  Column {
                    id: glanceDk
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14; spacing: 10
                    RowLayout {
                      width: parent.width; spacing: 10
                      Image {
                        source: "file:///usr/share/icons/hicolor/256x256/apps/docker.png"
                        sourceSize.width: 28; sourceSize.height: 28
                        width: 28; height: 28
                        fillMode: Image.PreserveAspectFit
                      }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Containers"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { textFormat: Text.PlainText; text: panel.runningDockerCount() + " running of " + hub.dockerContainers.length; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Column {
                      width: parent.width
                      spacing: 6
                      Text { visible: HubModel.trimText(hub.dockerError).length > 0; textFormat: Text.PlainText; text: hub.dockerError; color: "#ef4444"; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                      Text { visible: HubModel.trimText(hub.dockerError).length === 0 && hub.dockerContainers.length === 0; textFormat: Text.PlainText; text: "No containers found."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                      Column {
                        visible: HubModel.trimText(hub.dockerError).length === 0 && hub.dockerContainers.length > 0
                        width: parent.width
                        spacing: 4
                        Repeater {
                          model: Math.min(hub.dockerContainers.length, 5)
                          delegate: RowLayout {
                            required property int index
                            width: parent ? parent.width : 0
                            spacing: 8
                            Rectangle {
                              width: 8; height: 8; radius: 4
                              color: panel.dockerStateTone(hub.dockerContainers[index].state)
                              Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                              textFormat: Text.PlainText
                              text: hub.dockerContainers[index].name || "unknown"
                              color: Color.menu.text
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }
                            Text {
                              textFormat: Text.PlainText
                              text: hub.dockerContainers[index].state || ""
                              color: panel.dockerStateTone(hub.dockerContainers[index].state)
                              font.family: Style.font.family
                              font.pixelSize: Style.font.caption
                            }
                          }
                        }
                        Text {
                          visible: hub.dockerContainers.length > 5
                          textFormat: Text.PlainText
                          text: "+" + (hub.dockerContainers.length - 5) + " more"
                          color: softText(0.7)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }

                    Text { textFormat: Text.PlainText; text: "Open Containers tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  }
                }

                // Dev glance
                Rectangle {
                  width: 320
                  radius: 14
                  color: softText(0.045)
                  border.color: hub.codeServerRunning ? accentSoft(0.30) : accentSoft(0.16)
                  border.width: 1
                  implicitHeight: glanceDev.implicitHeight + 24
                  MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "dev" }
                  Column {
                    id: glanceDev
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14; spacing: 10
                    RowLayout {
                      width: parent.width; spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰅨"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Development"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text {
                          textFormat: Text.PlainText
                          text: HubModel.trimText(hub.preferredEditor).length > 0 ? ("Editor: " + HubModel.devToolLabel(hub.preferredEditor)) : "No preferred editor set"
                          color: softText(0.78)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Column {
                      width: parent.width
                      spacing: 6
                      Text { textFormat: Text.PlainText; text: "Repositories: " + (hub.devRepos ? hub.devRepos.length : 0); color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "VS Code Server: " + (hub.codeServerPresent ? hub.codeServerState : "not set up"); color: hub.codeServerRunning ? "#22c55e" : softText(0.82); font.family: Style.font.family }
                      Text { visible: HubModel.trimText(hub.devStatus).length > 0; textFormat: Text.PlainText; text: hub.devStatus; color: softText(0.68); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                    }

                    Text { textFormat: Text.PlainText; text: "Open Dev tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  }
                }

                // Games & storage glance
                Rectangle {
                  width: 320
                  radius: 14
                  color: softText(0.045)
                  border.color: accentSoft(0.18)
                  border.width: 1
                  implicitHeight: glanceGm.implicitHeight + 24
                  MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "games" }
                  Column {
                    id: glanceGm
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 14; spacing: 10
                    RowLayout {
                      width: parent.width; spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰊴"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Games & storage"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { textFormat: Text.PlainText; text: hub.gameMount; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                      Rectangle {
                        radius: 10
                        color: hub.gameMountPresent ? accentSoft(0.22) : softText(0.1)
                        implicitWidth: glanceMountBadge.implicitWidth + 14
                        implicitHeight: glanceMountBadge.implicitHeight + 8
                        Text { id: glanceMountBadge; anchors.centerIn: parent; textFormat: Text.PlainText; text: hub.gameMountPresent ? "mounted" : "not mounted"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Column {
                      width: parent.width
                      spacing: 8
                      Text {
                        visible: !hub.gameMountPresent
                        textFormat: Text.PlainText
                        text: "Game partition not mounted"
                        color: softText(0.8)
                        font.family: Style.font.family
                        wrapMode: Text.Wrap
                        width: parent.width
                      }
                      Column {
                        visible: hub.gameMountPresent
                        width: parent.width
                        spacing: 6
                        Rectangle {
                          width: parent.width
                          height: 10
                          radius: 5
                          color: softText(0.12)
                          clip: true
                          Rectangle {
                            height: parent.height
                            radius: 5
                            width: parent.width * hub.gameMountUseRatio
                            color: panel.storageUseColor(hub.gameMountUseRatio)
                            Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                          }
                        }
                        RowLayout {
                          width: parent.width
                          spacing: 8
                          Text { textFormat: Text.PlainText; text: (hub.gameMountUsePercentText.length > 0 ? hub.gameMountUsePercentText : Math.round(hub.gameMountUseRatio * 100) + "%") + " used"; color: panel.storageUseColor(hub.gameMountUseRatio); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                          Item { Layout.fillWidth: true }
                          Text { textFormat: Text.PlainText; text: HubModel.humanBytes(hub.gameMountUsedBytes) + " / " + HubModel.humanBytes(hub.gameMountTotalBytes); color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                        Text { textFormat: Text.PlainText; text: HubModel.humanBytes(hub.gameMountAvailBytes) + " free"; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                      Column {
                        width: parent.width
                        spacing: 2
                        Text { textFormat: Text.PlainText; text: "Steam: " + (hub.steamRunning ? "running" : "stopped") + " • games: " + (hub.steamGameCount >= 0 ? hub.steamGameCount : "?"); color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "Battle.net: " + (hub.bnetRunning ? "running" : "stopped") + " • games: " + (hub.bnetGameCount >= 0 ? hub.bnetGameCount : "?"); color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                    }

                    Text { textFormat: Text.PlainText; text: "Open Gaming tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                  }
                }
              }

            }

            Column {
              visible: panel.overviewSubTab === "update"
              width: parent.width
              spacing: Style.spacing.md

              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: omarchyUpdateCol.implicitHeight + 24
                Column {
                  id: omarchyUpdateCol
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
                      Text { textFormat: Text.PlainText; text: "Update Omarchy"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "Run Omarchy update in your default terminal (so you can answer prompts) while streaming live output below. The hub will try to focus the terminal."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                  }
                  Rectangle { width: parent.width; height: 1; color: softText(0.08) }
                  Text {
                    visible: HubModel.trimText(hub.omarchyUpdateStatus).length > 0
                    textFormat: Text.PlainText
                    text: hub.omarchyUpdateStatus
                    color: hub.omarchyUpdateStatus.indexOf("exited") === 0 ? "#ef4444" : softText(0.85)
                    font.family: Style.font.family
                    wrapMode: Text.Wrap
                    width: parent.width
                  }
                  Flow {
                    width: parent.width
                    spacing: 8
                    Button {
                      iconText: "󰚰"
                      text: hub.omarchyUpdateRunning ? "Updating…" : "Update Omarchy"
                      active: true
                      enabled: !hub.omarchyUpdateRunning
                      tooltipText: "Run omarchy-update and show live log"
                      onClicked: hub.runOmarchyUpdateInPanel()
                    }
                    Button {
                      iconText: "󰓛"
                      text: "Stop"
                      enabled: hub.omarchyUpdateRunning
                      tooltipText: "Stop live log/process"
                      onClicked: hub.stopOmarchyUpdateLog()
                    }
                    Button {
                      iconText: "󰆴"
                      text: "Clear log"
                      enabled: !hub.omarchyUpdateRunning && HubModel.trimText(hub.omarchyUpdateLog).length > 0
                      onClicked: hub.clearOmarchyUpdateLog()
                    }
                  }
                }
              }

              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.04)
                border.color: softText(0.10)
                border.width: 1
                implicitHeight: Math.max(220, omarchyLogCol.implicitHeight + 20)
                Column {
                  id: omarchyLogCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 10
                  spacing: 8
                  Text { textFormat: Text.PlainText; text: "Live log"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                  Rectangle {
                    width: parent.width
                    height: 320
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.18)
                    border.color: softText(0.08)
                    border.width: 1
                    clip: true
                    Flickable {
                      id: omarchyLogFlick
                      anchors.fill: parent
                      anchors.margins: 8
                      contentWidth: width
                      contentHeight: omarchyLogText.implicitHeight
                      clip: true
                      boundsBehavior: Flickable.StopAtBounds
                      Text {
                        id: omarchyLogText
                        width: omarchyLogFlick.width
                        textFormat: Text.PlainText
                        text: HubModel.trimText(hub.omarchyUpdateLog).length > 0 ? hub.omarchyUpdateLog : "No log output yet."
                        color: HubModel.trimText(hub.omarchyUpdateLog).length > 0 ? softText(0.92) : softText(0.55)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WrapAnywhere
                      }
                      onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    }
                  }
                }
              }
            }

          }

          // ACCESS TAB
          Column {
            visible: panel.currentTab === "access"
            width: parent.width
            spacing: Style.spacing.md

            // Access sub-nav
            Row {
              spacing: 8
              Button {
                iconText: "󰖂"
                text: "Tailnet"
                active: panel.accessSubTab === "tailnet"
                onClicked: panel.accessSubTab = "tailnet"
              }
              Button {
                iconText: "󰣀"
                text: "SSH"
                active: panel.accessSubTab === "ssh"
                onClicked: panel.accessSubTab = "ssh"
              }
            }

            Rectangle {
              visible: panel.accessSubTab === "tailnet"
              width: parent.width
              radius: Style.cornerRadius
              color: softText(0.04)
              border.color: softText(0.08)
              border.width: 1
              implicitHeight: tsMain.implicitHeight + 24
              Column {
                id: tsMain
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12; spacing: 10

                RowLayout {
                  id: tsTwoCol
                  width: parent.width
                  spacing: 16

                  // Left: Tailnet / this device / controls
                  Column {
                    id: tsLeft
                    Layout.preferredWidth: Math.max(280, parent.width * 0.42)
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    RowLayout {
                      width: parent.width; spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰖂"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Tailnet"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text {
                          textFormat: Text.PlainText
                          text: HubModel.trimText(hub.tailscaleTailnetName).length > 0 ? hub.tailscaleTailnetName : "unknown"
                          color: softText(0.85)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.body
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }
                      Rectangle {
                        radius: 10
                        color: hub.tailscaleActive === "active" ? accentSoft(0.22) : softText(0.1)
                        implicitWidth: tsBadge.implicitWidth + 14
                        implicitHeight: tsBadge.implicitHeight + 8
                        Text { id: tsBadge; anchors.centerIn: parent; textFormat: Text.PlainText; text: hub.tailscaleActive; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                    }

                    Text { textFormat: Text.PlainText; text: "Tailnet connection status, this device, peers, and service controls."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                    Text { textFormat: Text.PlainText; text: "tailscaled • enabled: " + hub.tailscaleEnabled; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    Text { visible: HubModel.trimText(hub.tailscaleNote).length > 0; textFormat: Text.PlainText; text: hub.tailscaleNote; color: Color.menu.text; font.family: Style.font.family; wrapMode: Text.Wrap; width: parent.width }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Text { textFormat: Text.PlainText; text: "This device"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                    Column {
                      visible: !!hub.tailscaleSelf
                      width: parent.width
                      spacing: 3
                      RowLayout {
                        width: parent.width; spacing: 8
                        Rectangle { width: 10; height: 10; radius: 5; color: "#22c55e" }
                        Text { textFormat: Text.PlainText; text: hub.tailscaleSelf ? (hub.tailscaleSelf.hostName || "vemberos") : "This device"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { visible: hub.tailscaleSelf && HubModel.trimText(hub.tailscaleSelf.os).length > 0; textFormat: Text.PlainText; text: hub.tailscaleSelf ? hub.tailscaleSelf.os : ""; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                      }
                      Text { visible: hub.tailscaleSelf && HubModel.trimText(hub.tailscaleSelf.dnsName).length > 0; textFormat: Text.PlainText; text: hub.tailscaleSelf ? hub.tailscaleSelf.dnsName : ""; color: softText(0.85); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                    }
                    Text { visible: !hub.tailscaleSelf; textFormat: Text.PlainText; text: "No device status available."; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Text { textFormat: Text.PlainText; text: "Service controls"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                    Flow {
                      width: parent.width
                      spacing: 8
                      Button { iconText: "󰐊"; text: "Start"; tooltipText: "pkexec systemctl start tailscaled"; enabled: !hub.tailscaleBusy; onClicked: hub.runTailscaleAction("start") }
                      Button { iconText: "󰓛"; text: "Stop"; tooltipText: "pkexec systemctl stop tailscaled"; enabled: !hub.tailscaleBusy; onClicked: hub.runTailscaleAction("stop") }
                      Button { iconText: "󰑐"; text: "Restart"; tooltipText: "pkexec systemctl restart tailscaled"; enabled: !hub.tailscaleBusy; onClicked: hub.runTailscaleAction("restart") }
                      Button { iconText: "󰆍"; text: "Start (terminal)"; tooltipText: "sudo in terminal"; onClicked: hub.runTailscaleActionInTerminal("start") }
                      Button { iconText: "󰆍"; text: "Restart (terminal)"; tooltipText: "sudo in terminal"; onClicked: hub.runTailscaleActionInTerminal("restart") }
                    }
                  }

                  // Divider
                  Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    color: softText(0.08)
                  }

                  // Right: Members
                  Column {
                    id: tsRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    RowLayout {
                      width: parent.width
                      Text { textFormat: Text.PlainText; text: "Members"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "(" + hub.tailscalePeers.length + ")"; color: softText(0.75); font.family: Style.font.family }
                      Item { Layout.fillWidth: true }
                    }

                    Text {
                      visible: hub.tailscalePeers.length === 0
                      textFormat: Text.PlainText
                      text: "No peer members found."
                      color: softText(0.7)
                      font.family: Style.font.family
                    }

                    Column {
                      width: parent.width
                      spacing: 0
                      Repeater {
                        model: hub.tailscalePeers
                        delegate: Column {
                          required property var modelData
                          required property int index
                          width: tsRight.width
                          spacing: 0

                          Rectangle {
                            visible: index > 0
                            width: parent.width
                            height: 1
                            color: softText(0.07)
                          }

                          RowLayout {
                            width: parent.width
                            height: implicitHeight
                            spacing: 10

                            Item {
                              Layout.preferredWidth: 14
                              Layout.preferredHeight: 36
                              Rectangle {
                                anchors.centerIn: parent
                                width: 10; height: 10; radius: 5
                                color: modelData.online ? "#22c55e" : "#ef4444"
                              }
                            }

                            Column {
                              Layout.fillWidth: true
                              Layout.topMargin: 8
                              Layout.bottomMargin: 8
                              spacing: 2
                              RowLayout {
                                width: parent.width; spacing: 8
                                Text {
                                  textFormat: Text.PlainText
                                  text: modelData.hostName || modelData.dnsName || "Unknown"
                                  color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                  textFormat: Text.PlainText
                                  text: modelData.online ? "online" : "offline"
                                  color: modelData.online ? "#22c55e" : "#ef4444"
                                  font.family: Style.font.family; font.pixelSize: Style.font.caption
                                }
                              }
                              Text {
                                visible: HubModel.trimText(modelData.dnsName).length > 0
                                textFormat: Text.PlainText
                                text: modelData.dnsName
                                color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width
                              }
                            }

                            Column {
                              Layout.alignment: Qt.AlignVCenter
                              spacing: 2
                              Text {
                                visible: modelData.ips && modelData.ips.length > 0
                                textFormat: Text.PlainText
                                text: modelData.ips && modelData.ips.length > 0 ? modelData.ips[0] : ""
                                color: softText(0.88); font.family: Style.font.family; font.pixelSize: Style.font.caption
                                horizontalAlignment: Text.AlignRight
                              }
                              Text {
                                visible: HubModel.trimText(modelData.os).length > 0
                                textFormat: Text.PlainText
                                text: modelData.os
                                color: softText(0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption
                                horizontalAlignment: Text.AlignRight
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // SSH
            Rectangle {
              visible: panel.accessSubTab === "ssh"
              width: parent.width
              radius: Style.cornerRadius
              color: softText(0.04)
              border.color: softText(0.08)
              border.width: 1
              implicitHeight: sshCol.implicitHeight + 24
              Column {
                id: sshCol
                property string authKeysView: "keys"
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12; spacing: 10

                RowLayout {
                  width: parent.width; spacing: 10
                  Text { textFormat: Text.PlainText; text: "󰣀"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                  ColumnLayout {
                    Layout.fillWidth: true; spacing: 2
                    Text { textFormat: Text.PlainText; text: "SSH"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                    Text { textFormat: Text.PlainText; text: "SSH service status and authorized key management for remote access to this machine."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    Text { textFormat: Text.PlainText; text: "Host: " + (HubModel.trimText(hub.sshHostName).length > 0 ? hub.sshHostName : "vemberos"); color: softText(0.82); font.family: Style.font.family; font.pixelSize: Style.font.body }
                  }
                  Rectangle {
                    radius: 10
                    color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : softText(0.1)
                    border.color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
                    border.width: hub.sshActive === "active" ? 1 : 0
                    implicitWidth: sshBadge.implicitWidth + 14
                    implicitHeight: sshBadge.implicitHeight + 8
                    Text {
                      id: sshBadge
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: hub.sshActive
                      color: hub.sshActive === "active" ? "#22c55e" : Color.menu.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: hub.sshActive === "active"
                    }
                  }
                }

                Text { textFormat: Text.PlainText; text: "sshd • enabled: " + hub.sshEnabled; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }

                Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                Text { textFormat: Text.PlainText; text: "Authorized keys"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
                Text { textFormat: Text.PlainText; text: "Manage public keys allowed to sign in over SSH. Add a key, select one to review/remove, or open the file for manual edits."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                Text {
                  visible: HubModel.trimText(hub.sshAuthorizedKeysStatus).length > 0
                  textFormat: Text.PlainText
                  text: hub.sshAuthorizedKeysStatus
                  color: softText(0.85)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                  width: parent.width
                }

                Column {
                  visible: HubModel.trimText(hub.sshGeneratedPublicKey).length > 0
                  width: parent.width
                  spacing: 6
                  Text { textFormat: Text.PlainText; text: "Generated public key"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                  Rectangle {
                    width: parent.width
                    radius: 8
                    color: softText(0.03)
                    border.color: accentSoft(0.2)
                    border.width: 1
                    implicitHeight: Math.max(56, genPubKeyText.implicitHeight + 12)
                    TextEdit {
                      id: genPubKeyText
                      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                      anchors.margins: 8
                      text: hub.sshGeneratedPublicKey
                      color: Color.menu.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: TextEdit.WrapAnywhere
                      readOnly: true
                      selectByMouse: true
                      selectionColor: accentSoft(0.35)
                      selectedTextColor: Color.menu.text
                    }
                  }
                }

                // Nav bar
                Rectangle {
                  width: parent.width
                  radius: 10
                  color: softText(0.03)
                  border.color: softText(0.08)
                  border.width: 1
                  implicitHeight: authNavRow.implicitHeight + 10
                  Row {
                    id: authNavRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 6
                    spacing: 6
                    Button {
                      iconText: "󰌋"
                      text: "Keys"
                      active: sshCol.authKeysView === "keys"
                      onClicked: sshCol.authKeysView = "keys"
                    }
                    Button {
                      iconText: "󰐕"
                      text: "Add key"
                      active: sshCol.authKeysView === "add"
                      onClicked: sshCol.authKeysView = "add"
                    }
                    Button {
                      iconText: "󰌆"
                      text: hub.sshGenerateBusy ? "Generating…" : "Generate key"
                      tooltipText: "Generate a new SSH identity keypair (~/.ssh/id_ed25519)"
                      enabled: !hub.sshGenerateBusy
                      onClicked: hub.generateSshIdentityKey()
                    }
                    Item { width: 8; height: 1 }
                    Button {
                      iconText: "󰏫"
                      text: "Open editor"
                      tooltipText: "Open ~/.ssh/authorized_keys in editor"
                      onClicked: hub.openAuthorizedKeysEditor()
                    }
                  }
                }

                // Keys view (list + details)
                RowLayout {
                  visible: sshCol.authKeysView === "keys"
                  width: parent.width
                  spacing: 12

                  // Left: keys list
                  Column {
                    id: authKeysLeft
                    Layout.preferredWidth: Math.max(260, parent.width * 0.42)
                    Layout.alignment: Qt.AlignTop
                    spacing: 6

                    Text {
                      visible: !hub.sshAuthorizedKeys || hub.sshAuthorizedKeys.length === 0
                      textFormat: Text.PlainText
                      text: "No authorized keys found."
                      color: softText(0.7)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }

                    Repeater {
                      model: hub.sshAuthorizedKeys || []
                      delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: authKeysLeft.width
                        radius: 8
                        color: hub.sshSelectedKeyIndex === index ? accentSoft(0.14) : softText(0.03)
                        border.color: hub.sshSelectedKeyIndex === index ? accentSoft(0.35) : softText(0.08)
                        border.width: 1
                        implicitHeight: keyItemCol.implicitHeight + 12
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: hub.sshSelectedKeyIndex = (hub.sshSelectedKeyIndex === index ? -1 : index)
                        }
                        Column {
                          id: keyItemCol
                          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                          anchors.margins: 8
                          spacing: 2
                          Text {
                            textFormat: Text.PlainText
                            text: HubModel.trimText(modelData.comment || "").length > 0 ? modelData.comment : (modelData.type || "Key")
                            color: Color.menu.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                          }
                          Text {
                            textFormat: Text.PlainText
                            text: (modelData.type || "key") + " • " + (modelData.keyPreview || "")
                            color: softText(0.72)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                            width: parent.width
                          }
                        }
                      }
                    }
                  }

                  // Divider
                  Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.minimumHeight: 120
                    color: softText(0.08)
                  }

                  // Right: details
                  Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 10

                    Text { textFormat: Text.PlainText; text: "Selected key"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                    Text {
                      visible: hub.sshSelectedKeyIndex < 0 || hub.sshSelectedKeyIndex >= (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
                      textFormat: Text.PlainText
                      text: "Select a key to view details, remove it, or switch to Add key."
                      color: softText(0.7)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                      width: parent.width
                    }
                    Column {
                      visible: hub.sshSelectedKeyIndex >= 0 && hub.sshSelectedKeyIndex < (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
                      width: parent.width
                      spacing: 6
                      Text {
                        textFormat: Text.PlainText
                        text: "Type: " + (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] ? (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].type || "unknown") : "")
                        color: Color.menu.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: "Comment: " + (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] && HubModel.trimText(hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].comment).length > 0 ? hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].comment : "(none)")
                        color: Color.menu.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.Wrap
                        width: parent.width
                      }
                      Rectangle {
                        width: parent.width
                        radius: 8
                        color: softText(0.03)
                        border.color: softText(0.08)
                        border.width: 1
                        implicitHeight: selKeyText.implicitHeight + 12
                        Text {
                          id: selKeyText
                          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                          anchors.margins: 8
                          textFormat: Text.PlainText
                          text: hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] ? (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].line || "") : ""
                          color: softText(0.85)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          wrapMode: Text.WrapAnywhere
                          width: parent.width
                        }
                      }
                      Flow {
                        width: parent.width
                        spacing: 8
                        Button {
                          iconText: "󰆴"
                          text: "Remove selected"
                          tooltipText: "Remove the selected key from authorized_keys"
                          enabled: hub.sshSelectedKeyIndex >= 0 && hub.sshSelectedKeyIndex < (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
                          onClicked: panel.confirmRemoveSshKey = true
                        }
                      }
                    }
                  }
                }

                // Add key view
                Column {
                  visible: sshCol.authKeysView === "add"
                  width: parent.width
                  spacing: 10
                  Text { textFormat: Text.PlainText; text: "Add authorized key"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                  Text { textFormat: Text.PlainText; text: "Paste a public key (single line) to append to ~/.ssh/authorized_keys. Use Open editor for bulk or advanced edits."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                  Rectangle {
                    width: parent.width
                    radius: 8
                    color: softText(0.03)
                    border.color: softText(0.08)
                    border.width: 1
                    implicitHeight: 90
                    TextInput {
                      id: newKeyInput
                      anchors.fill: parent
                      anchors.margins: 8
                      color: Color.menu.text
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: TextInput.WrapAnywhere
                      selectByMouse: true
                      clip: true
                      text: hub.sshNewKeyText
                      onTextChanged: hub.sshNewKeyText = text
                    }
                  }
                  Flow {
                    width: parent.width
                    spacing: 8
                    Button {
                      iconText: "󰐕"
                      text: "Add key"
                      tooltipText: "Append this public key to authorized_keys"
                      onClicked: hub.addAuthorizedKey()
                    }
                  }
                }
              }
            }
          }

          // CONTAINERS TAB
          Column {
            id: containersTab
            visible: panel.currentTab === "containers"
            width: parent.width
            spacing: Style.spacing.md
            property int selectedContainerIndex: -1

            Row {
              spacing: 8
              Button {
                iconText: "󰡨"
                text: "Containers"
                active: panel.containersSubTab === "containers"
                onClicked: panel.containersSubTab = "containers"
              }
              Button {
                iconText: "󰃢"
                text: "Prune"
                active: panel.containersSubTab === "prune"
                onClicked: panel.containersSubTab = "prune"
              }
              Button {
                iconText: "󰡨"
                text: "Docker Hub"
                active: panel.containersSubTab === "hub"
                onClicked: panel.containersSubTab = "hub"
              }
            }

            Column {
              visible: panel.containersSubTab === "containers"
              width: parent.width
              spacing: Style.spacing.md

              Text {
                textFormat: Text.PlainText
                text: "View and manage Docker containers. Select a container to see details and actions."
                color: softText(0.8)
                font.family: Style.font.family
                wrapMode: Text.Wrap
                width: parent.width
              }

              RowLayout {
                width: parent.width
                spacing: 12

                // Left: container list
                Column {
                  id: containersLeft
                  Layout.preferredWidth: Math.max(280, parent.width * 0.42)
                  Layout.alignment: Qt.AlignTop
                  spacing: 6

                  Text {
                    visible: hub.dockerContainers.length === 0
                    textFormat: Text.PlainText
                    text: "No containers found."
                    color: softText(0.7)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  Repeater {
                    model: hub.dockerContainers
                    delegate: Rectangle {
                      required property var modelData
                      required property int index
                      width: containersLeft.width
                      radius: 8
                      color: containersTab.selectedContainerIndex === index ? accentSoft(0.14) : softText(0.03)
                      border.color: containersTab.selectedContainerIndex === index ? accentSoft(0.35) : softText(0.08)
                      border.width: 1
                      implicitHeight: ctrItemCol.implicitHeight + 12
                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: containersTab.selectedContainerIndex = index
                      }
                      RowLayout {
                        id: ctrItemCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 8
                        Rectangle {
                          width: 10; height: 10; radius: 5
                          color: panel.dockerStateTone(modelData.state)
                          Layout.alignment: Qt.AlignVCenter
                        }
                        Column {
                          Layout.fillWidth: true
                          spacing: 2
                          Text {
                            textFormat: Text.PlainText
                            text: modelData.name || "unknown"
                            color: Color.menu.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                          }
                          Text {
                            visible: HubModel.trimText(modelData.image).length > 0
                            textFormat: Text.PlainText
                            text: modelData.image
                            color: softText(0.7)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                            width: parent.width
                          }
                        }
                        Text {
                          textFormat: Text.PlainText
                          text: modelData.state || ""
                          color: panel.dockerStateTone(modelData.state)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }
                  }
                }

                // Divider
                Rectangle {
                  Layout.preferredWidth: 1
                  Layout.fillHeight: true
                  Layout.minimumHeight: 160
                  color: softText(0.08)
                }

                // Right: details
                Column {
                  id: containerDetails
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignTop
                  spacing: 10

                  property var selected: (containersTab.selectedContainerIndex >= 0 && containersTab.selectedContainerIndex < hub.dockerContainers.length) ? hub.dockerContainers[containersTab.selectedContainerIndex] : null
                  property bool selBusy: selected ? (hub.dockerBusy && hub.dockerBusyName === selected.name) : false
                  property bool selPulling: selected ? (hub.dockerPullActive && hub.dockerPullingName === selected.name) : false
                  property bool selPullResult: selected ? (!hub.dockerPullActive && hub.dockerPullingName === selected.name && HubModel.trimText(hub.dockerPullStatus).length > 0) : false

                  onSelectedChanged: {
                    if (hub && hub.refreshDockerDetailSize)
                      hub.refreshDockerDetailSize(selected ? selected.name : "");
                  }

                  Text {
                    visible: !containerDetails.selected
                    textFormat: Text.PlainText
                    text: "Select a container to view details and actions."
                    color: softText(0.7)
                    font.family: Style.font.family
                    wrapMode: Text.Wrap
                    width: parent.width
                  }

                  Column {
                    visible: !!containerDetails.selected
                    width: parent.width
                    spacing: 10

                    RowLayout {
                      width: parent.width
                      spacing: 10
                      Rectangle {
                        width: 12; height: 12; radius: 6
                        color: panel.dockerStateTone(containerDetails.selected ? containerDetails.selected.state : "")
                        Layout.alignment: Qt.AlignVCenter
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: containerDetails.selected ? (containerDetails.selected.name || "unknown") : ""
                        color: Color.menu.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.heading
                        font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: containerDetails.selected ? (containerDetails.selected.state || "") : ""
                        color: panel.dockerStateTone(containerDetails.selected ? containerDetails.selected.state : "")
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Text {
                      visible: HubModel.trimText(containerDetails.selected ? (containerDetails.selected.image || "") : "").length > 0
                      textFormat: Text.PlainText
                      text: "Image: " + (containerDetails.selected ? (containerDetails.selected.image || "") : "")
                      color: softText(0.85)
                      font.family: Style.font.family
                      wrapMode: Text.WrapAnywhere
                      width: parent.width
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: "Status: " + (containerDetails.selected ? (containerDetails.selected.status || containerDetails.selected.state || "unknown") : "")
                      color: Color.menu.text
                      font.family: Style.font.family
                      wrapMode: Text.Wrap
                      width: parent.width
                    }

                    RowLayout {
                      width: parent.width
                      spacing: 8
                      Text {
                        textFormat: Text.PlainText
                        text: "Size:"
                        color: Color.menu.text
                        font.family: Style.font.family
                      }
                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: {
                          if (!containerDetails.selected) return "";
                          if (hub.dockerDetailSizeBusy && hub.dockerDetailSizeName === containerDetails.selected.name) return "Querying…";
                          if (hub.dockerDetailSizeName === containerDetails.selected.name && HubModel.trimText(hub.dockerDetailSizeError).length > 0) return hub.dockerDetailSizeError;
                          if (hub.dockerDetailSizeName === containerDetails.selected.name && HubModel.trimText(hub.dockerDetailSizeText).length > 0) return hub.dockerDetailSizeText;
                          return "—";
                        }
                        color: (hub.dockerDetailSizeName === (containerDetails.selected ? containerDetails.selected.name : "") && HubModel.trimText(hub.dockerDetailSizeError).length > 0) ? "#ef4444" : softText(0.9)
                        font.family: Style.font.family
                        wrapMode: Text.Wrap
                      }
                      Button {
                        visible: !!containerDetails.selected
                        iconText: "󰑐"
                        text: "Query"
                        enabled: !!containerDetails.selected && !(hub.dockerDetailSizeBusy && hub.dockerDetailSizeName === containerDetails.selected.name)
                        tooltipText: "Query container disk size (docker ps -s)"
                        onClicked: if (containerDetails.selected) hub.refreshDockerDetailSize(containerDetails.selected.name)
                      }
                    }
                    Text {
                      visible: !!containerDetails.selected && hub.dockerDetailSizeName === containerDetails.selected.name && HubModel.trimText(hub.dockerDetailSizeText).length > 0
                      textFormat: Text.PlainText
                      text: "Writable layer / virtual size (as reported by Docker)."
                      color: softText(0.65)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                      width: parent.width
                    }

                    // Pull progress/result
                    Column {
                      visible: containerDetails.selPulling || containerDetails.selPullResult
                      width: parent.width
                      spacing: 6
                      Rectangle {
                        width: parent.width
                        radius: 8
                        color: accentSoft(0.10)
                        border.color: accentSoft(0.20)
                        border.width: 1
                        implicitHeight: pullInfoCol.implicitHeight + 12
                        Column {
                          id: pullInfoCol
                          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                          anchors.margins: 8
                          spacing: 6
                          Text {
                            textFormat: Text.PlainText
                            text: containerDetails.selPulling ? hub.dockerPullStatus : (hub.dockerPullResult.length > 0 ? hub.dockerPullResult : hub.dockerPullStatus)
                            color: Color.menu.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.Wrap
                            width: parent.width
                          }
                          Rectangle {
                            visible: containerDetails.selPulling
                            width: parent.width
                            height: 8
                            radius: 4
                            color: softText(0.12)
                            clip: true
                            Rectangle {
                              id: selProgressFill
                              height: parent.height
                              radius: 4
                              color: Color.accent
                              width: hub.dockerPullPercent >= 0 ? (parent.width * hub.dockerPullPercent) : (parent.width * 0.35)
                              x: hub.dockerPullPercent >= 0 ? 0 : -width
                              Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                              SequentialAnimation on x {
                                running: hub.dockerPullPercent < 0 && containerDetails.selPulling
                                loops: Animation.Infinite
                                NumberAnimation { from: -selProgressFill.width; to: selProgressTrackW.width; duration: Style.duration(1200); easing.type: Easing.InOutQuad }
                              }
                            }
                            Item { id: selProgressTrackW; anchors.fill: parent }
                          }
                        }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Flow {
                      width: parent.width
                      spacing: 8
                      Button {
                        iconText: "󰐊"
                        text: "Start"
                        enabled: !containerDetails.selBusy && !!containerDetails.selected
                        onClicked: if (containerDetails.selected) hub.runDockerAction("start", containerDetails.selected.name)
                      }
                      Button {
                        iconText: "󰓛"
                        text: "Stop"
                        enabled: !containerDetails.selBusy && !!containerDetails.selected
                        onClicked: if (containerDetails.selected) hub.runDockerAction("stop", containerDetails.selected.name)
                      }
                      Button {
                        iconText: "󰑐"
                        text: "Restart"
                        enabled: !containerDetails.selBusy && !!containerDetails.selected
                        onClicked: if (containerDetails.selected) hub.runDockerAction("restart", containerDetails.selected.name)
                      }
                      Button {
                        iconText: "󰚰"
                        text: containerDetails.selPulling ? "Pulling…" : "Pull image"
                        enabled: !containerDetails.selBusy && !!containerDetails.selected && HubModel.trimText(containerDetails.selected.image || "").length > 0
                        tooltipText: containerDetails.selected ? ("Pull / update image: " + (containerDetails.selected.image || "")) : ""
                        onClicked: if (containerDetails.selected) hub.runDockerPull(containerDetails.selected.image, containerDetails.selected.name)
                      }
                    }
                  }
                }
              }
            }

            Column {
              visible: panel.containersSubTab === "prune"
              width: parent.width
              spacing: Style.spacing.md

              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: pruneCol.implicitHeight + 24
                Column {
                  id: pruneCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 14
                  spacing: 12
                  RowLayout {
                    width: parent.width
                    spacing: 10
                    Text { textFormat: Text.PlainText; text: "󰃢"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2
                      Text { textFormat: Text.PlainText; text: "Prune stopped containers"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "Remove all stopped containers to free disk space (docker container prune -f). Running containers are not affected."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                  }
                  Rectangle { width: parent.width; height: 1; color: softText(0.08) }
                  Text {
                    textFormat: Text.PlainText
                    text: "Containers: " + panel.runningDockerCount() + " running / " + (hub.dockerContainers ? hub.dockerContainers.length : 0) + " total"
                    color: softText(0.85)
                    font.family: Style.font.family
                    wrapMode: Text.Wrap
                    width: parent.width
                  }
                  Text {
                    visible: HubModel.trimText(hub.dockerError).length > 0
                    textFormat: Text.PlainText
                    text: hub.dockerError
                    color: "#ef4444"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.Wrap
                    width: parent.width
                  }
                  Text {
                    visible: hub.dockerPruneBusy || HubModel.trimText(hub.lastActionMessage).indexOf("Prun") === 0 || HubModel.trimText(hub.lastActionMessage).indexOf("Docker container prune") === 0
                    textFormat: Text.PlainText
                    text: hub.dockerPruneBusy ? "Pruning stopped containers…" : hub.lastActionMessage
                    color: (!hub.dockerPruneBusy && hub.lastActionMessage.indexOf("failed") !== -1) ? "#ef4444" : softText(0.85)
                    font.family: Style.font.family
                    wrapMode: Text.Wrap
                    width: parent.width
                  }
                  Flow {
                    width: parent.width
                    spacing: 8
                    Button {
                      iconText: "󰃢"
                      text: hub.dockerPruneBusy ? "Pruning…" : "Prune stopped containers"
                      active: true
                      tooltipText: "Remove all stopped containers (docker container prune -f)"
                      enabled: !hub.dockerPruneBusy && !hub.dockerBusy
                      onClicked: panel.confirmPrune = true
                    }
                  }
                }
              }
            }

            Column {
              visible: panel.containersSubTab === "hub"
              width: parent.width
              spacing: Style.spacing.md

              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: dockerHubCol.implicitHeight + 24
                Column {
                  id: dockerHubCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 14
                  spacing: 12
                  RowLayout {
                    width: parent.width
                    spacing: 10
                    Text { textFormat: Text.PlainText; text: "󰡨"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2
                      Text { textFormat: Text.PlainText; text: "Docker Hub"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "Browse images, tags, and documentation on Docker Hub."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                  }
                  Rectangle { width: parent.width; height: 1; color: softText(0.08) }
                  Text { textFormat: Text.PlainText; text: "Find official images and community containers, then pull them from the Containers tab."; color: softText(0.85); font.family: Style.font.family; wrapMode: Text.Wrap; width: parent.width }
                  Flow {
                    width: parent.width
                    spacing: 8
                    Button {
                      iconText: "󰖟"
                      text: "Open Docker Hub"
                      active: true
                      tooltipText: "Open https://hub.docker.com in your browser"
                      onClicked: Qt.openUrlExternally("https://hub.docker.com")
                    }
                    Button {
                      iconText: "󰍉"
                      text: "Explore images"
                      tooltipText: "Browse Docker Hub explore page"
                      onClicked: Qt.openUrlExternally("https://hub.docker.com/search?q=&type=image")
                    }
                  }
                }
              }
            }
          }

          // GAMES TAB
          Column {
            visible: panel.currentTab === "games"
            width: parent.width
            spacing: Style.spacing.md

            // Gaming sub-nav
            Row {
              spacing: 8
              Button {
                iconText: "󰊴"
                text: "Launchers"
                active: panel.gamesSubTab === "launchers"
                onClicked: panel.gamesSubTab = "launchers"
              }
              Button {
                iconText: "󰀻"
                text: "Apps"
                active: panel.gamesSubTab === "apps"
                onClicked: panel.gamesSubTab = "apps"
              }
              Button {
                iconText: "󰒋"
                text: "Servers"
                active: panel.gamesSubTab === "servers"
                onClicked: panel.gamesSubTab = "servers"
              }
              Button {
                iconText: "󰋊"
                text: "Storage"
                active: panel.gamesSubTab === "storage"
                onClicked: panel.gamesSubTab = "storage"
              }
            }

            // Launchers tab
            Column {
              visible: panel.gamesSubTab === "launchers"
              width: parent.width
              spacing: Style.spacing.md

              // Launcher bar (installed launchers only)
              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: launcherBarCol.implicitHeight + 20
                Column {
                  id: launcherBarCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 10
                  spacing: 8
                  Text { textFormat: Text.PlainText; text: "Launcher bar"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                  Text { textFormat: Text.PlainText; text: "Quick launch for installed game launchers."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                  Flow {
                    width: parent.width
                    spacing: 8
                    Button {
                      visible: hub.steamInstalled
                      iconText: "󰓓"
                      text: "Steam"
                      tooltipText: "Launch Steam"
                      onClicked: hub.launchSteam()
                    }
                    Button {
                      visible: hub.bnetInstalled
                      iconText: "󰖺"
                      text: "Battle.net"
                      tooltipText: "Launch Battle.net"
                      onClicked: hub.launchBattleNet()
                    }
                    Repeater {
                      model: {
                        var out = [];
                        var apps = hub.extraApps || [];
                        for (var i = 0; i < apps.length; i++) {
                          var a = apps[i];
                          if (a && a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) out.push(a);
                        }
                        return out;
                      }
                      delegate: Button {
                        required property var modelData
                        iconText: modelData.id === "heroic" ? "󰊗" : (modelData.id === "lutris" ? "󰺷" : (modelData.id === "prismlauncher" ? "󰍳" : (modelData.id === "minecraft-launcher" ? "󰍳" : (modelData.id === "curseforge" ? "󰏗" : "󰐊"))))
                        text: modelData.name || modelData.id
                        tooltipText: "Launch " + (modelData.name || modelData.id)
                        onClicked: hub.launchExtraApp(modelData.id)
                      }
                    }
                    Text {
                      visible: !hub.steamInstalled && !hub.bnetInstalled && (function() {
                        var apps = hub.extraApps || [];
                        for (var i = 0; i < apps.length; i++) { var a = apps[i]; if (a && a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) return false; }
                        return true;
                      })()
                      textFormat: Text.PlainText
                      text: "No installed launchers detected."
                      color: softText(0.7)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }

              Text { visible: hub.extraAppsScanBusy; textFormat: Text.PlainText; text: "Scanning launchers and apps…"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { visible: HubModel.trimText(hub.extraAppInstallStatus).length > 0; textFormat: Text.PlainText; text: hub.extraAppInstallStatus; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }

              // Live install log (shared runner)
              Rectangle {
                visible: !hub.installIsDev && (hub.installRunning || HubModel.trimText(hub.installLog).length > 0)
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.04)
                border.color: hub.installRunning ? accentSoft(0.30) : softText(0.10)
                border.width: 1
                implicitHeight: installLogColL.implicitHeight + 20
                Column {
                  id: installLogColL
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 12
                  spacing: 8
                  RowLayout {
                    width: parent.width
                    spacing: 8
                    Text { textFormat: Text.PlainText; text: "󰏔"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    Text { Layout.fillWidth: true; textFormat: Text.PlainText; text: (HubModel.trimText(hub.installTitle).length > 0 ? hub.installTitle : "Install") + (hub.installRunning ? " • running" : " • log"); color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight }
                    Button { visible: hub.installRunning; iconText: "󰓛"; text: "Stop"; tooltipText: "Stop tracking this install"; onClicked: hub.stopInstall() }
                    Button { enabled: !hub.installRunning; iconText: "󰆴"; text: "Clear"; tooltipText: "Clear the install log"; onClicked: hub.clearInstallLog() }
                  }
                  Rectangle {
                    width: parent.width
                    height: 200
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.18)
                    border.color: softText(0.08)
                    border.width: 1
                    clip: true
                    Flickable {
                      id: installLogFlickL
                      anchors.fill: parent
                      anchors.margins: 8
                      contentWidth: width
                      contentHeight: installLogTextL.implicitHeight
                      clip: true
                      boundsBehavior: Flickable.StopAtBounds
                      Text {
                        id: installLogTextL
                        width: installLogFlickL.width
                        textFormat: Text.PlainText
                        text: HubModel.trimText(hub.installLog).length > 0 ? hub.installLog : "Waiting for output…"
                        color: HubModel.trimText(hub.installLog).length > 0 ? softText(0.92) : softText(0.55)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WrapAnywhere
                      }
                      onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    }
                  }
                }
              }

              // Game library summary (total + per-launcher breakdown)
              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: libraryCol.implicitHeight + 24
                Column {
                  id: libraryCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 14
                  spacing: 12

                  property int steamCount: hub.steamGameCount >= 0 ? hub.steamGameCount : 0
                  property int bnetCount: hub.bnetGameCount >= 0 ? hub.bnetGameCount : 0
                  property int totalKnownGames: steamCount + bnetCount
                  property bool hasKnownCounts: hub.steamGameCount >= 0 || hub.bnetGameCount >= 0
                  property var installedExtraLaunchers: {
                    var out = [];
                    var apps = hub.extraApps || [];
                    for (var i = 0; i < apps.length; i++) {
                      var a = apps[i];
                      if (a && a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) out.push(a);
                    }
                    return out;
                  }
                  property bool hasAnyInstalled: hub.steamInstalled || hub.bnetInstalled || installedExtraLaunchers.length > 0

                  Column {
                    width: parent.width
                    spacing: 2
                    Text {
                      textFormat: Text.PlainText
                      text: libraryCol.hasKnownCounts ? String(libraryCol.totalKnownGames) : "—"
                      color: Color.menu.text
                      font.family: Style.font.family
                      font.pixelSize: Math.round(Style.font.heading * 2.2)
                      font.bold: true
                    }
                    Text {
                      textFormat: Text.PlainText
                      text: libraryCol.hasKnownCounts ? "games detected" : "game count unavailable"
                      color: softText(0.72)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Column {
                    visible: libraryCol.hasAnyInstalled
                    width: parent.width
                    spacing: 10

                    // Steam
                    Column {
                      visible: hub.steamInstalled
                      width: parent.width
                      spacing: 4
                      RowLayout {
                        width: parent.width
                        spacing: 8
                        Rectangle { width: 10; height: 10; radius: 2; color: "#66c0f4"; Layout.alignment: Qt.AlignVCenter }
                        Text { textFormat: Text.PlainText; text: "Steam"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true }
                        Text { textFormat: Text.PlainText; text: hub.steamGameCount >= 0 ? String(hub.steamGameCount) : "—"; color: "#66c0f4"; font.family: Style.font.family; font.bold: true }
                      }
                      Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: softText(0.10)
                        clip: true
                        Rectangle {
                          height: parent.height
                          radius: 3
                          width: libraryCol.totalKnownGames > 0 ? parent.width * (libraryCol.steamCount / libraryCol.totalKnownGames) : 0
                          color: "#66c0f4"
                          Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                        }
                      }
                    }

                    // Battle.net
                    Column {
                      visible: hub.bnetInstalled
                      width: parent.width
                      spacing: 4
                      RowLayout {
                        width: parent.width
                        spacing: 8
                        Rectangle { width: 10; height: 10; radius: 2; color: "#00aeff"; Layout.alignment: Qt.AlignVCenter }
                        Text { textFormat: Text.PlainText; text: "Battle.net"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true }
                        Text { textFormat: Text.PlainText; text: hub.bnetGameCount >= 0 ? String(hub.bnetGameCount) : "—"; color: "#00aeff"; font.family: Style.font.family; font.bold: true }
                      }
                      Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: softText(0.10)
                        clip: true
                        Rectangle {
                          height: parent.height
                          radius: 3
                          width: libraryCol.totalKnownGames > 0 ? parent.width * (libraryCol.bnetCount / libraryCol.totalKnownGames) : 0
                          color: "#00aeff"
                          Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                        }
                      }
                    }

                    Text {
                      visible: libraryCol.installedExtraLaunchers.length > 0
                      textFormat: Text.PlainText
                      text: {
                        var names = [];
                        var list = libraryCol.installedExtraLaunchers || [];
                        for (var i = 0; i < list.length; i++) { if (list[i] && list[i].name) names.push(list[i].name); }
                        return "Also installed: " + names.join(", ");
                      }
                      color: softText(0.65)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                      width: parent.width
                    }
                  }

                  Text {
                    visible: !libraryCol.hasAnyInstalled
                    textFormat: Text.PlainText
                    text: "No game launchers detected. Add one below to get started."
                    color: softText(0.75)
                    font.family: Style.font.family
                    wrapMode: Text.Wrap
                    width: parent.width
                  }
                }
              }

              // Available to add (not installed)
              Column {
                width: parent.width
                spacing: 8
                property var offerItems: {
                  var out = [];
                  if (!hub.steamInstalled) out.push({ kind: "steam", id: "steam", name: "Steam", description: "Valve game platform and library.", icon: "󰓓" });
                  if (!hub.bnetInstalled) out.push({ kind: "bnet", id: "battlenet", name: "Battle.net", description: "Blizzard launcher (best-effort detection/prefix).", icon: "󰖺" });
                  var apps = hub.extraApps || [];
                  for (var i = 0; i < apps.length; i++) {
                    var a = apps[i];
                    if (a && !a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) out.push({ kind: "extra", id: a.id, name: a.name, description: a.description || "", icon: a.id === "heroic" ? "󰊗" : (a.id === "lutris" ? "󰺷" : (a.id === "prismlauncher" ? "󰍳" : (a.id === "minecraft-launcher" ? "󰍳" : (a.id === "curseforge" ? "󰏗" : "󰊴")))) });
                  }
                  return out;
                }
                visible: offerItems.length > 0

                Text { textFormat: Text.PlainText; text: "Available to add"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { textFormat: Text.PlainText; text: "Install launchers to track and launch games from this hub."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }

                Flow {
                  width: parent.width
                  spacing: 14
                  Repeater {
                    model: parent.parent.offerItems
                    delegate: Rectangle {
                      required property var modelData
                      width: 320
                      radius: 14
                      color: softText(0.045)
                      border.color: softText(0.10)
                      border.width: 1
                      implicitHeight: offerCol.implicitHeight + 20
                      Column {
                        id: offerCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                          width: parent.width
                          spacing: 10
                          Text { textFormat: Text.PlainText; text: modelData.icon || "󰊴"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 28 }
                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { textFormat: Text.PlainText; text: modelData.name || modelData.id; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                            Text { textFormat: Text.PlainText; text: "Not installed"; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                          }
                        }
                        Rectangle { width: parent.width; height: 1; color: softText(0.08) }
                        Text { textFormat: Text.PlainText; text: modelData.description || ""; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                        Flow {
                          width: parent.width
                          spacing: 8
                          Button {
                            iconText: modelData.id === "minecraft-launcher" ? "󰐕" : "󰏔"
                            text: (hub.installRunning && hub.installRunningId === modelData.id) ? "Installing…" : (modelData.kind === "bnet" ? "Set up" : (modelData.id === "minecraft-launcher" ? "Add" : "Install"))
                            tooltipText: modelData.kind === "steam" ? "Install Steam in the default terminal (answer the sudo prompt there)" : (modelData.kind === "bnet" ? "Open the Lutris Battle.net install page" : (modelData.id === "minecraft-launcher" ? "Add/install Minecraft Launcher" : ("Open terminal to install " + modelData.name)))
                            enabled: !hub.installRunning
                            onClicked: {
                              if (modelData.kind === "extra") hub.installExtraApp(modelData.id);
                              else if (modelData.kind === "steam") hub.installSteam();
                              else if (modelData.kind === "bnet") hub.openBattlenetSetup();
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Apps tab
            Column {
              visible: panel.gamesSubTab === "apps"
              width: parent.width
              spacing: Style.spacing.md

              Text { visible: hub.extraAppsScanBusy; textFormat: Text.PlainText; text: "Scanning launchers and apps…"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { visible: HubModel.trimText(hub.extraAppInstallStatus).length > 0; textFormat: Text.PlainText; text: hub.extraAppInstallStatus; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }

              // Live install log (shared runner)
              Rectangle {
                visible: !hub.installIsDev && (hub.installRunning || HubModel.trimText(hub.installLog).length > 0)
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.04)
                border.color: hub.installRunning ? accentSoft(0.30) : softText(0.10)
                border.width: 1
                implicitHeight: installLogColA.implicitHeight + 20
                Column {
                  id: installLogColA
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 12
                  spacing: 8
                  RowLayout {
                    width: parent.width
                    spacing: 8
                    Text { textFormat: Text.PlainText; text: "󰏔"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    Text { Layout.fillWidth: true; textFormat: Text.PlainText; text: (HubModel.trimText(hub.installTitle).length > 0 ? hub.installTitle : "Install") + (hub.installRunning ? " • running" : " • log"); color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight }
                    Button { visible: hub.installRunning; iconText: "󰓛"; text: "Stop"; tooltipText: "Stop tracking this install"; onClicked: hub.stopInstall() }
                    Button { enabled: !hub.installRunning; iconText: "󰆴"; text: "Clear"; tooltipText: "Clear the install log"; onClicked: hub.clearInstallLog() }
                  }
                  Rectangle {
                    width: parent.width
                    height: 200
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.18)
                    border.color: softText(0.08)
                    border.width: 1
                    clip: true
                    Flickable {
                      id: installLogFlickA
                      anchors.fill: parent
                      anchors.margins: 8
                      contentWidth: width
                      contentHeight: installLogTextA.implicitHeight
                      clip: true
                      boundsBehavior: Flickable.StopAtBounds
                      Text {
                        id: installLogTextA
                        width: installLogFlickA.width
                        textFormat: Text.PlainText
                        text: HubModel.trimText(hub.installLog).length > 0 ? hub.installLog : "Waiting for output…"
                        color: HubModel.trimText(hub.installLog).length > 0 ? softText(0.92) : softText(0.55)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WrapAnywhere
                      }
                      onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    }
                  }
                }
              }

              // Installed apps
              Column {
                width: parent.width
                spacing: 8
                property var installedApps: {
                  var out = [];
                  var apps = hub.extraApps || [];
                  for (var i = 0; i < apps.length; i++) {
                    var a = apps[i];
                    if (a && a.category === "apps" && a.installed) out.push(a);
                  }
                  return out;
                }
                visible: installedApps.length > 0

                Text { textFormat: Text.PlainText; text: "Installed apps"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Flow {
                  width: parent.width
                  spacing: 14
                  Repeater {
                    model: parent.parent.installedApps
                    delegate: Rectangle {
                      required property var modelData
                      width: 320
                      radius: 14
                      color: softText(0.045)
                      border.color: modelData.running ? accentSoft(0.35) : softText(0.10)
                      border.width: 1
                      implicitHeight: appInstalledCol.implicitHeight + 20
                      Column {
                        id: appInstalledCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                          width: parent.width
                          spacing: 10
                          Text { textFormat: Text.PlainText; text: modelData.id === "discord" ? "󰙯" : "󰀻"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 28 }
                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { textFormat: Text.PlainText; text: modelData.name || modelData.id; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                            Text { textFormat: Text.PlainText; text: modelData.running ? "Installed • running" : "Installed"; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                          }
                        }
                        Rectangle { width: parent.width; height: 1; color: softText(0.08) }
                        Text { visible: HubModel.trimText(modelData.description || "").length > 0; textFormat: Text.PlainText; text: modelData.description || ""; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                        Flow {
                          width: parent.width
                          spacing: 8
                          Button {
                            iconText: "󰐊"
                            text: "Launch"
                            onClicked: hub.launchExtraApp(modelData.id)
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Offers (not installed)
              Column {
                width: parent.width
                spacing: 8
                property var offerApps: {
                  var out = [];
                  var apps = hub.extraApps || [];
                  for (var i = 0; i < apps.length; i++) {
                    var a = apps[i];
                    if (a && a.category === "apps" && !a.installed) out.push(a);
                  }
                  return out;
                }
                visible: offerApps.length > 0

                Text { textFormat: Text.PlainText; text: "Available to add"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Flow {
                  width: parent.width
                  spacing: 14
                  Repeater {
                    model: parent.parent.offerApps
                    delegate: Rectangle {
                      required property var modelData
                      width: 320
                      radius: 14
                      color: softText(0.045)
                      border.color: softText(0.10)
                      border.width: 1
                      implicitHeight: appOfferCol.implicitHeight + 20
                      Column {
                        id: appOfferCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                          width: parent.width
                          spacing: 10
                          Text { textFormat: Text.PlainText; text: modelData.id === "discord" ? "󰙯" : "󰀻"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 28 }
                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { textFormat: Text.PlainText; text: modelData.name || modelData.id; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                            Text { textFormat: Text.PlainText; text: "Not installed"; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                          }
                        }
                        Rectangle { width: parent.width; height: 1; color: softText(0.08) }
                        Text { visible: HubModel.trimText(modelData.description || "").length > 0; textFormat: Text.PlainText; text: modelData.description || ""; color: softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                        Flow {
                          width: parent.width
                          spacing: 8
                          Button {
                            iconText: "󰏔"
                            text: (hub.installRunning && hub.installRunningId === modelData.id) ? "Installing…" : "Install"
                            tooltipText: "Install " + (modelData.name || modelData.id) + " in the default terminal"
                            enabled: !hub.installRunning
                            onClicked: hub.installExtraApp(modelData.id)
                          }
                        }
                      }
                    }
                  }
                }
              }

              Text {
                visible: (function() {
                  var apps = hub.extraApps || [];
                  var hasAny = false;
                  for (var i = 0; i < apps.length; i++) { if (apps[i] && apps[i].category === "apps") { hasAny = true; break; } }
                  return !hasAny;
                })() && !hub.extraAppsScanBusy
                textFormat: Text.PlainText
                text: "No app offers configured."
                color: softText(0.7)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            // Servers tab
            Column {
              visible: panel.gamesSubTab === "servers"
              width: parent.width
              spacing: Style.spacing.md

              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: gameServersCol.implicitHeight + 24
                Column {
                  id: gameServersCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 14
                  spacing: 10
                  RowLayout {
                    width: parent.width; spacing: 10
                    Text { textFormat: Text.PlainText; text: "󰒋"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    ColumnLayout {
                      Layout.fillWidth: true; spacing: 2
                      Text { textFormat: Text.PlainText; text: "Game servers"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "Detected game server containers (Docker) and Steam dedicated servers installed on this host (best-effort). Container controls are available for Docker servers."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                  }

                  Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                  property var detectedGameServers: {
                    var out = [];
                    var list = hub.dockerContainers || [];
                    var keys = ["minecraft", "valheim", "factorio", "palworld", "terraria", "ark", "cs2", "csgo", "rust", "satisfactory", "7dtd", "zomboid", "projectzomboid", "enshrouded", "foundry", "vintage", "vrising", "conan", "dayz", "game", "gameserver", "pterodactyl", "crafty", "steamcmd"];
                    for (var i = 0; i < list.length; i++) {
                      var c = list[i] || {};
                      var hay = ((c.name || "") + " " + (c.image || "")).toLowerCase();
                      var match = false;
                      for (var k = 0; k < keys.length; k++) { if (hay.indexOf(keys[k]) !== -1) { match = true; break; } }
                      if (match) out.push({ serverType: "container", name: c.name || "unknown", image: c.image || "", state: c.state || "", status: c.status || "" });
                    }
                    var steamServers = hub.steamDedicatedServers || [];
                    for (var s = 0; s < steamServers.length; s++) {
                      var ss = steamServers[s] || {};
                      out.push({ serverType: "steam", name: ss.name || "Steam Dedicated Server", image: ss.appid ? ("AppID " + ss.appid) : "Steam dedicated server", state: "installed", status: ss.installdir ? ("Install dir: " + ss.installdir) : "Host install (Steam)", installdir: ss.installdir || "", appid: ss.appid || "" });
                    }
                    return out;
                  }

                  Text {
                    visible: (gameServersCol.detectedGameServers || []).length === 0
                    textFormat: Text.PlainText
                    text: HubModel.trimText(hub.dockerError).length > 0 ? hub.dockerError : "No game servers detected. Docker game server containers and installed Steam dedicated servers will appear here."
                    color: HubModel.trimText(hub.dockerError).length > 0 ? "#ef4444" : softText(0.75)
                    font.family: Style.font.family
                    wrapMode: Text.Wrap
                    width: parent.width
                  }

                  Repeater {
                    model: gameServersCol.detectedGameServers || []
                    delegate: Rectangle {
                      required property var modelData
                      width: gameServersCol.width - 0
                      radius: 8
                      color: softText(0.03)
                      border.color: softText(0.08)
                      border.width: 1
                      implicitHeight: gsRow.implicitHeight + 16
                      Column {
                        id: gsRow
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6
                        RowLayout {
                          width: parent.width
                          spacing: 8
                          Rectangle { width: 10; height: 10; radius: 5; color: modelData.serverType === "steam" ? "#66c0f4" : panel.dockerStateTone(modelData.state); Layout.alignment: Qt.AlignVCenter }
                          ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { textFormat: Text.PlainText; text: modelData.name || "unknown"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { visible: HubModel.trimText(modelData.image || "").length > 0; textFormat: Text.PlainText; text: modelData.image; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; Layout.fillWidth: true }
                          }
                          Text { textFormat: Text.PlainText; text: modelData.serverType === "steam" ? "Steam" : (modelData.state || ""); color: modelData.serverType === "steam" ? "#66c0f4" : panel.dockerStateTone(modelData.state); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        }
                        Text { visible: HubModel.trimText(modelData.status || "").length > 0; textFormat: Text.PlainText; text: modelData.status; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                        Flow {
                          visible: modelData.serverType !== "steam"
                          width: parent.width
                          spacing: 8
                          Button {
                            iconText: "󰐊"
                            text: "Start"
                            enabled: !hub.dockerBusy
                            onClicked: hub.runDockerAction("start", modelData.name)
                          }
                          Button {
                            iconText: "󰓛"
                            text: "Stop"
                            enabled: !hub.dockerBusy
                            onClicked: hub.runDockerAction("stop", modelData.name)
                          }
                          Button {
                            iconText: "󰑐"
                            text: "Restart"
                            enabled: !hub.dockerBusy
                            onClicked: hub.runDockerAction("restart", modelData.name)
                          }
                        }
                        Text {
                          visible: modelData.serverType === "steam"
                          textFormat: Text.PlainText
                          text: "Host-installed Steam dedicated server (not a Docker container)."
                          color: softText(0.65)
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          wrapMode: Text.Wrap
                          width: parent.width
                        }
                      }
                    }
                  }
                }
              }
            }

            // Storage tab
            Column {
              visible: panel.gamesSubTab === "storage"
              width: parent.width
              spacing: Style.spacing.md

              Rectangle {
                width: parent.width
                radius: Style.cornerRadius
                color: softText(0.05)
                border.color: accentSoft(0.18)
                border.width: 1
                implicitHeight: storageInfoCol.implicitHeight + 24
                Column {
                  id: storageInfoCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 14
                  spacing: 12
                  RowLayout {
                    width: parent.width; spacing: 10
                    Text { textFormat: Text.PlainText; text: "󰋊"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    ColumnLayout {
                      Layout.fillWidth: true; spacing: 2
                      Text { textFormat: Text.PlainText; text: "Game partition • " + hub.gameMount; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                      Column {
                        visible: hub.gameMountPresent
                        Layout.fillWidth: true
                        spacing: 6
                        Rectangle {
                          width: parent.width
                          height: 12
                          radius: 6
                          color: softText(0.12)
                          clip: true
                          Rectangle {
                            height: parent.height
                            radius: 6
                            width: parent.width * hub.gameMountUseRatio
                            color: panel.storageUseColor(hub.gameMountUseRatio)
                            Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                          }
                        }
                        RowLayout {
                          width: parent.width
                          spacing: 8
                          Text {
                            textFormat: Text.PlainText
                            text: (hub.gameMountUsePercentText.length > 0 ? hub.gameMountUsePercentText : Math.round(hub.gameMountUseRatio * 100) + "%") + " used"
                            color: panel.storageUseColor(hub.gameMountUseRatio)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }
                          Item { Layout.fillWidth: true }
                          Text {
                            textFormat: Text.PlainText
                            text: HubModel.humanBytes(hub.gameMountUsedBytes) + " used • " + HubModel.humanBytes(hub.gameMountAvailBytes) + " free • " + HubModel.humanBytes(hub.gameMountTotalBytes) + " total"
                            color: Color.menu.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                          }
                        }
                      }
                      Text {
                        visible: !hub.gameMountPresent
                        textFormat: Text.PlainText
                        text: "Not mounted / not found"
                        color: softText(0.85); font.family: Style.font.family; wrapMode: Text.Wrap; Layout.fillWidth: true
                      }
                      Text { visible: HubModel.trimText(hub.gameMountError).length > 0; textFormat: Text.PlainText; text: hub.gameMountError; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                    Rectangle {
                      radius: 10
                      color: hub.gameMountPresent ? accentSoft(0.22) : softText(0.1)
                      implicitWidth: mountBadge3.implicitWidth + 14
                      implicitHeight: mountBadge3.implicitHeight + 8
                      Text { id: mountBadge3; anchors.centerIn: parent; textFormat: Text.PlainText; text: hub.gameMountPresent ? "mounted" : "not mounted"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                  }
                }
              }
            }
          }

          // DEV TAB
          Column {
            visible: panel.currentTab === "dev"
            width: parent.width
            spacing: Style.spacing.md

            // Dev sub-nav
            Row {
              spacing: 8
              Button {
                iconText: "󰊢"
                text: "Workspace"
                active: panel.devSubTab === "workspace"
                onClicked: panel.devSubTab = "workspace"
              }
              Button {
                iconText: "󰅨"
                text: "Tools"
                active: panel.devSubTab === "tools"
                onClicked: panel.devSubTab = "tools"
              }
              Button {
                iconText: hub.preferredEditor === "vscode" ? "󰨞" : "󰅱"
                text: HubModel.trimText(hub.preferredEditor).length > 0 ? HubModel.devToolLabel(hub.preferredEditor) : "Zed"
                tooltipText: "Local editor for opening repos (click to toggle Zed / VS Code)"
                onClicked: hub.setPreferredEditor(hub.preferredEditor === "zed" ? "vscode" : "zed")
              }
              Button {
                iconText: "󰖟"
                text: "Code Server (Docker)"
                active: panel.devSubTab === "codeserver"
                onClicked: panel.devSubTab = "codeserver"
              }
            }

            Text {
              visible: HubModel.trimText(hub.devStatus).length > 0
              textFormat: Text.PlainText
              text: hub.devStatus
              color: softText(0.78)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }
            Text {
              visible: HubModel.trimText(hub.devError).length > 0
              textFormat: Text.PlainText
              text: hub.devError
              color: "#ef4444"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }

            // Workspace (repos + details)
            Column {
              visible: panel.devSubTab === "workspace"
              width: parent.width
              spacing: Style.spacing.md

              RowLayout {
                width: parent.width
                spacing: 12

                // Left: repos list
                Rectangle {
                  Layout.preferredWidth: Math.max(320, parent.width * 0.44)
                  Layout.alignment: Qt.AlignTop
                  radius: Style.cornerRadius
                  color: softText(0.04)
                  border.color: softText(0.08)
                  border.width: 1
                  implicitHeight: devReposCol.implicitHeight + 24
                  Column {
                    id: devReposCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                      width: parent.width
                      spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰊢"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Repositories"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { textFormat: Text.PlainText; text: "Select a repository to view details (size, git info) and open it in your editor."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                      }
                      Text { textFormat: Text.PlainText; text: String((hub.devRepos || []).length); color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Text {
                      visible: !hub.devRepos || hub.devRepos.length === 0
                      textFormat: Text.PlainText
                      text: hub.devBusy ? "Scanning…" : "No repositories found in scanned locations."
                      color: softText(0.7)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }

                    Repeater {
                      model: hub.devRepos || []
                      delegate: Rectangle {
                        required property var modelData
                        width: devReposCol.width - 0
                        radius: 8
                        color: hub.devSelectedRepoPath === modelData.path ? accentSoft(0.14) : softText(0.03)
                        border.color: hub.devSelectedRepoPath === modelData.path ? accentSoft(0.35) : softText(0.08)
                        border.width: 1
                        implicitHeight: repoRow.implicitHeight + 10
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: hub.selectDevRepo(modelData.path)
                        }
                        Column {
                          id: repoRow
                          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                          anchors.margins: 8
                          spacing: 2
                          Text {
                            textFormat: Text.PlainText
                            text: modelData.name || modelData.path || "repo"
                            color: Color.menu.text
                            font.family: Style.font.family
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                          }
                          Text {
                            textFormat: Text.PlainText
                            text: modelData.path || ""
                            color: softText(0.68)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideMiddle
                            width: parent.width
                          }
                        }
                      }
                    }
                  }
                }

                // Right: repo details
                Rectangle {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignTop
                  radius: Style.cornerRadius
                  color: softText(0.04)
                  border.color: softText(0.08)
                  border.width: 1
                  implicitHeight: repoDetailsCol.implicitHeight + 24
                  Column {
                    id: repoDetailsCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                      width: parent.width
                      spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰋼"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "Details"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText(hub.devSelectedRepoPath).length > 0 ? hub.devSelectedRepoPath : "Select a repository to see its details."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Text {
                      visible: HubModel.trimText(hub.devSelectedRepoPath).length === 0
                      textFormat: Text.PlainText
                      text: "No repository selected."
                      color: softText(0.7)
                      font.family: Style.font.family
                    }

                    Text {
                      visible: HubModel.trimText(hub.devSelectedRepoPath).length > 0 && hub.devRepoDetailBusy
                      textFormat: Text.PlainText
                      text: "Loading details…"
                      color: softText(0.75)
                      font.family: Style.font.family
                    }

                    Column {
                      visible: HubModel.trimText(hub.devSelectedRepoPath).length > 0 && !hub.devRepoDetailBusy
                      width: parent.width
                      spacing: 8

                      GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        Text { textFormat: Text.PlainText; text: "Folder size"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText((hub.devRepoDetail || {}).size).length > 0 ? hub.devRepoDetail.size : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

                        Text { textFormat: Text.PlainText; text: "Last modified"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText((hub.devRepoDetail || {}).mtime).length > 0 ? hub.devRepoDetail.mtime : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

                        Text { textFormat: Text.PlainText; text: "Git branch"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText((hub.devRepoDetail || {}).branch).length > 0 ? hub.devRepoDetail.branch : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

                        Text { textFormat: Text.PlainText; text: "Working tree"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText((hub.devRepoDetail || {}).dirty).length > 0 ? hub.devRepoDetail.dirty : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

                        Text { textFormat: Text.PlainText; text: "Remote (origin)"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText((hub.devRepoDetail || {}).remote).length > 0 ? hub.devRepoDetail.remote : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }

                        Text { textFormat: Text.PlainText; text: "Last commit"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText((hub.devRepoDetail || {}).last).length > 0 ? hub.devRepoDetail.last : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }
                      }

                      Flow {
                        width: parent.width
                        spacing: 8
                        Button {
                          iconText: "󰏌"
                          text: "Open in " + (HubModel.trimText(hub.preferredEditor).length > 0 ? HubModel.devToolLabel(hub.preferredEditor) : "editor")
                          enabled: HubModel.trimText(hub.devSelectedRepoPath).length > 0 && HubModel.trimText(hub.preferredEditor).length > 0
                          tooltipText: HubModel.trimText(hub.preferredEditor).length > 0 ? ("Open in " + HubModel.devToolLabel(hub.preferredEditor)) : "Select a preferred editor in the bar above"
                          onClicked: hub.openRepoInEditor(hub.devSelectedRepoPath)
                        }
                        Button {
                          iconText: "󰑐"
                          text: "Refresh details"
                          enabled: HubModel.trimText(hub.devSelectedRepoPath).length > 0 && !hub.devRepoDetailBusy
                          onClicked: hub.selectDevRepo(hub.devSelectedRepoPath)
                        }
                      }
                    }
                  }
                }
              }
            }

            // Tools
            Column {
              visible: panel.devSubTab === "tools"
              width: parent.width
              spacing: Style.spacing.md

              // Live install log for terminal tool installs
              Rectangle {
                visible: hub.installRunningId.indexOf("dev:") === 0 && (hub.installRunning || HubModel.trimText(hub.installLog).length > 0)
                width: Math.min(parent.width, 720)
                radius: Style.cornerRadius
                color: softText(0.04)
                border.color: hub.installRunning ? accentSoft(0.30) : softText(0.10)
                border.width: 1
                implicitHeight: devInstallLogCol.implicitHeight + 20
                Column {
                  id: devInstallLogCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 12
                  spacing: 8
                  RowLayout {
                    width: parent.width
                    spacing: 8
                    Text { textFormat: Text.PlainText; text: "󰏔"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    Text { Layout.fillWidth: true; textFormat: Text.PlainText; text: (HubModel.trimText(hub.installTitle).length > 0 ? hub.installTitle : "Install") + (hub.installRunning ? " • running" : " • log"); color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight }
                    Button { visible: hub.installRunning; iconText: "󰓛"; text: "Stop"; tooltipText: "Stop tracking this install"; onClicked: hub.stopInstall() }
                    Button { enabled: !hub.installRunning; iconText: "󰆴"; text: "Clear"; tooltipText: "Clear the install log"; onClicked: hub.clearInstallLog() }
                  }
                  Rectangle {
                    width: parent.width
                    height: 180
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.18)
                    border.color: softText(0.08)
                    border.width: 1
                    clip: true
                    Flickable {
                      id: devInstallLogFlick
                      anchors.fill: parent
                      anchors.margins: 8
                      contentWidth: width
                      contentHeight: devInstallLogText.implicitHeight
                      clip: true
                      boundsBehavior: Flickable.StopAtBounds
                      Text {
                        id: devInstallLogText
                        width: devInstallLogFlick.width
                        textFormat: Text.PlainText
                        text: HubModel.trimText(hub.installLog).length > 0 ? hub.installLog : "Waiting for output…"
                        color: HubModel.trimText(hub.installLog).length > 0 ? softText(0.92) : softText(0.55)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WrapAnywhere
                      }
                      onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    }
                  }
                }
              }

              Rectangle {
                width: Math.min(parent.width, 720)
                radius: Style.cornerRadius
                color: softText(0.04)
                border.color: softText(0.08)
                border.width: 1
                implicitHeight: devToolsCol.implicitHeight + 24
                Column {
                  id: devToolsCol
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                  anchors.margins: 12
                  spacing: 10

                  RowLayout {
                    width: parent.width
                    spacing: 10
                    Text { textFormat: Text.PlainText; text: "󰅨"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                    ColumnLayout {
                      Layout.fillWidth: true; spacing: 2
                      Text { textFormat: Text.PlainText; text: "Tools"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "Toolchain and editor installs for this server."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                    }
                  }

                  Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                  Repeater {
                    model: hub.devTools || []
                    delegate: Rectangle {
                      required property var modelData
                      width: devToolsCol.width - 0
                      radius: 8
                      color: softText(0.03)
                      border.color: softText(0.08)
                      border.width: 1
                      implicitHeight: toolRow.implicitHeight + 12
                      RowLayout {
                        id: toolRow
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 8
                        Rectangle {
                          width: 10; height: 10; radius: 5
                          color: modelData.installed ? "#22c55e" : softText(0.35)
                          Layout.alignment: Qt.AlignVCenter
                        }
                        Column {
                          Layout.fillWidth: true
                          spacing: 2
                          Text {
                            textFormat: Text.PlainText
                            text: HubModel.devToolLabel(modelData.id)
                            color: Color.menu.text
                            font.family: Style.font.family
                            font.bold: true
                          }
                          Text {
                            textFormat: Text.PlainText
                            text: modelData.installed ? (HubModel.trimText(modelData.version).length > 0 ? modelData.version : (modelData.path || "Installed")) : "Not installed"
                            color: modelData.installed ? softText(0.78) : softText(0.65)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            width: parent.width
                          }
                          Text {
                            visible: modelData.installed && HubModel.trimText(modelData.path).length > 0
                            textFormat: Text.PlainText
                            text: modelData.path
                            color: softText(0.6)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideMiddle
                            width: parent.width
                          }
                        }
                        Column {
                          visible: !modelData.installed
                          spacing: 4
                          Layout.alignment: Qt.AlignVCenter
                          Row {
                            spacing: 6
                            Button {
                              iconText: "󰏔"
                              text: (hub.devInstallBusy && hub.devInstallToolId === modelData.id) ? "Installing…" : "Install"
                              tooltipText: "Try silent install for " + HubModel.devToolLabel(modelData.id)
                              enabled: !hub.devInstallBusy && !hub.installRunning
                              onClicked: hub.runDevInstallSilent(modelData.id)
                            }
                            Button {
                              iconText: "󰆍"
                              text: (hub.installRunning && hub.installRunningId === ("dev:" + modelData.id)) ? "Installing…" : "Terminal"
                              tooltipText: "Open the default terminal to install " + HubModel.devToolLabel(modelData.id)
                              enabled: !hub.devInstallBusy && !hub.installRunning
                              onClicked: hub.openDevInstallTerminal(modelData.id)
                            }
                          }
                          Text {
                            visible: hub.devInstallBusy && hub.devInstallToolId === modelData.id
                            textFormat: Text.PlainText
                            text: "Running…"
                            color: softText(0.7)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                          }
                        }
                        Text {
                          visible: modelData.installed
                          textFormat: Text.PlainText
                          text: "Installed"
                          color: "#22c55e"
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }
                  }
                }
              }
            }

            // Code Server (Docker) mapped view
            Column {
              visible: panel.devSubTab === "codeserver"
              width: parent.width
              spacing: Style.spacing.md

              RowLayout {
                width: parent.width
                spacing: 12

                // Status & actions
                Rectangle {
                  Layout.preferredWidth: Math.max(320, parent.width * 0.46)
                  Layout.alignment: Qt.AlignTop
                  radius: Style.cornerRadius
                  color: softText(0.04)
                  border.color: accentSoft(hub.codeServerRunning ? 0.28 : 0.14)
                  border.width: 1
                  implicitHeight: codeServerStatusCol.implicitHeight + 24
                  Column {
                    id: codeServerStatusCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                      width: parent.width
                      spacing: 10
                      Text { textFormat: Text.PlainText; text: "󰨞"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
                      ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { textFormat: Text.PlainText; text: "VS Code Server"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                        Text { textFormat: Text.PlainText; text: "Browser-based editor in Docker (code-server)"; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                      }
                      Rectangle {
                        radius: 10
                        color: hub.codeServerRunning ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : softText(0.1)
                        border.color: hub.codeServerRunning ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
                        border.width: hub.codeServerRunning ? 1 : 0
                        implicitWidth: codeServerBadge2.implicitWidth + 14
                        implicitHeight: codeServerBadge2.implicitHeight + 8
                        Text {
                          id: codeServerBadge2
                          anchors.centerIn: parent
                          textFormat: Text.PlainText
                          text: hub.codeServerPresent ? hub.codeServerState : "not set up"
                          color: hub.codeServerRunning ? "#22c55e" : Color.menu.text
                          font.family: Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: hub.codeServerRunning
                        }
                      }
                    }

                    Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                    Text {
                      visible: HubModel.trimText(hub.codeServerStatusText).length > 0
                      textFormat: Text.PlainText
                      text: hub.codeServerStatusText
                      color: softText(0.82)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                      width: parent.width
                    }

                    Column {
                      visible: hub.codeServerBusy || hub.codeServerSetupStage === "preparing" || hub.codeServerSetupStage === "pulling" || hub.codeServerSetupStage === "creating" || hub.codeServerSetupStage === "starting" || hub.codeServerSetupStage === "provisioning" || hub.codeServerSetupStage === "running" || hub.codeServerSetupStage === "launching" || hub.codeServerSetupStage === "checking" || hub.codeServerSetupStage === "error" || hub.codeServerSetupStage === "exists" || hub.codeServerSetupStage === "done"
                      width: parent.width
                      spacing: 6

                      Text {
                        textFormat: Text.PlainText
                        text: HubModel.trimText(hub.codeServerSetupDetail).length > 0 ? hub.codeServerSetupDetail : "Setting up VS Code Server…"
                        color: hub.codeServerSetupStage === "error" ? "#ef4444" : softText(0.82)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.Wrap
                        width: parent.width
                      }

                      Text {
                        visible: hub.codeServerSetupBytesTotal > 0
                        textFormat: Text.PlainText
                        text: HubModel.humanBytes(hub.codeServerSetupBytesDone) + " / " + HubModel.humanBytes(hub.codeServerSetupBytesTotal) + " (" + Math.round(Math.max(0, Math.min(1, hub.codeServerSetupProgress)) * 100) + "%)"
                        color: softText(0.75)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                      }

                      Rectangle {
                        visible: hub.codeServerBusy || hub.codeServerSetupStage === "pulling" || hub.codeServerSetupStage === "creating" || hub.codeServerSetupStage === "starting" || hub.codeServerSetupStage === "preparing" || hub.codeServerSetupStage === "provisioning"
                        width: parent.width
                        height: 8
                        radius: 4
                        color: softText(0.12)
                        clip: true
                        Rectangle {
                          id: codeServerSetupProgressFill
                          height: parent.height
                          radius: 4
                          color: hub.codeServerSetupStage === "error" ? "#ef4444" : Color.accent
                          width: hub.codeServerSetupProgress > 0 ? (parent.width * Math.max(0, Math.min(1, hub.codeServerSetupProgress))) : (parent.width * 0.35)
                          x: hub.codeServerSetupProgress > 0 ? 0 : -width
                          Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
                          SequentialAnimation on x {
                            running: (hub.codeServerSetupProgress <= 0) && (hub.codeServerBusy || hub.codeServerSetupStage === "preparing" || hub.codeServerSetupStage === "pulling" || hub.codeServerSetupStage === "creating" || hub.codeServerSetupStage === "starting" || hub.codeServerSetupStage === "provisioning")
                            loops: Animation.Infinite
                            NumberAnimation { from: -codeServerSetupProgressFill.width; to: codeServerSetupProgressFill.parent ? codeServerSetupProgressFill.parent.width : 300; duration: Style.duration(1200); easing.type: Easing.InOutQuad }
                          }
                        }
                      }

                      Rectangle {
                        visible: HubModel.trimText(hub.codeServerSetupLog).length > 0
                        width: parent.width
                        radius: 8
                        color: softText(0.03)
                        border.color: softText(0.08)
                        border.width: 1
                        implicitHeight: Math.min(180, setupLogText.implicitHeight + 16)
                        clip: true

                        Flickable {
                          id: setupLogFlick
                          anchors.fill: parent
                          anchors.margins: 8
                          contentWidth: width
                          contentHeight: setupLogText.implicitHeight
                          clip: true
                          boundsBehavior: Flickable.StopAtBounds
                          Text {
                            id: setupLogText
                            width: setupLogFlick.width
                            textFormat: Text.PlainText
                            text: hub.codeServerSetupLog
                            color: softText(0.78)
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                            wrapMode: Text.WrapAnywhere
                          }
                          onContentHeightChanged: {
                            if (contentHeight > height) contentY = contentHeight - height;
                          }
                        }
                      }
                    }

                    Column {
                      width: parent.width
                      spacing: 4
                      Text { textFormat: Text.PlainText; text: "Actions"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                      Flow {
                        width: parent.width
                        spacing: 8
                        Button {
                          visible: !hub.codeServerPresent
                          iconText: "󰏔"
                          text: hub.codeServerBusy ? "Working…" : "Set up"
                          tooltipText: "Configure and create the VS Code Server container"
                          enabled: !hub.codeServerBusy
                          active: true
                          onClicked: {
                            panel.codeServerSetupPassword = "";
                            panel.codeServerSetupPort = String(hub.codeServerPort || 8443);
                            panel.codeServerSetupOpen = true;
                          }
                        }
                        Button {
                          visible: hub.codeServerPresent && !hub.codeServerRunning
                          iconText: "󰐊"
                          text: "Start"
                          enabled: !hub.codeServerBusy
                          onClicked: hub.startCodeServer()
                        }
                        Button {
                          visible: hub.codeServerPresent && hub.codeServerRunning
                          iconText: "󰓛"
                          text: "Stop"
                          enabled: !hub.codeServerBusy
                          onClicked: hub.stopCodeServer()
                        }
                        Button {
                          visible: hub.codeServerPresent
                          iconText: "󰖟"
                          text: "Open in browser"
                          tooltipText: "Open VS Code Server in browser"
                          enabled: hub.codeServerRunning
                          active: hub.codeServerRunning
                          onClicked: hub.openCodeServer()
                        }
                        Button {
                          iconText: "󰑐"
                          text: "Refresh"
                          tooltipText: "Refresh VS Code Server container status"
                          enabled: !hub.codeServerBusy
                          onClicked: hub.refreshCodeServer()
                        }
                        Button {
                          visible: hub.codeServerPresent
                          iconText: "󰆴"
                          text: "Uninstall"
                          tooltipText: "Remove the VS Code Server container"
                          enabled: !hub.codeServerBusy
                          onClicked: panel.confirmRemoveCodeServer = true
                        }
                      }
                    }

                    Text {
                      visible: !hub.codeServerPresent
                      textFormat: Text.PlainText
                      text: "Set a password and port in the hub. Setup creates the container, installs Python, uv, and GitHub CLI (gh), installs Python extensions (ms-python.python, ms-python.debugpy, charliermarsh.ruff), and prepares a default Python workspace in ~/Projects. Progress and debug logs are shown in the panel. Password is stored in a restricted env file (not in config.yaml)."
                      color: softText(0.72)
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                      width: parent.width
                    }
                  }
                }

                // Map/details
                Column {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignTop
                  spacing: 12

                  Rectangle {
                    width: parent.width
                    radius: Style.cornerRadius
                    color: softText(0.04)
                    border.color: softText(0.08)
                    border.width: 1
                    implicitHeight: codeServerMapCol.implicitHeight + 24
                    Column {
                      id: codeServerMapCol
                      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                      anchors.margins: 12
                      spacing: 10

                      RowLayout {
                        width: parent.width
                        spacing: 10
                        Text { textFormat: Text.PlainText; text: "󰘦"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                        ColumnLayout {
                          Layout.fillWidth: true; spacing: 2
                          Text { textFormat: Text.PlainText; text: "Docker map"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                          Text { textFormat: Text.PlainText; text: "How the VS Code Server container is set up on this machine."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                      }

                      Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                      GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        Text { textFormat: Text.PlainText; text: "Container"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "vember-code-server"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Image"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: HubModel.trimText(hub.codeServerImage).length > 0 ? hub.codeServerImage : "codercom/code-server:latest"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Port"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "localhost:" + hub.codeServerPort + " → container:8080"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Home mount"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "$HOME → /home/coder/home"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Config"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "~/.config/vember-code-server → /home/coder/.config"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "User data"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "~/.config/vember-code-server/user-data → /home/coder/.local/share/code-server (extensions/settings)"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Tools bin"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "~/.config/vember-code-server/bin → /home/coder/.local/bin (uv/uvx)"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Default open"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "No folder (open a project when needed)"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

                        Text { textFormat: Text.PlainText; text: "Restart"; color: softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                        Text { textFormat: Text.PlainText; text: "unless-stopped"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }
                      }
                    }
                  }

                  Rectangle {
                    width: parent.width
                    radius: Style.cornerRadius
                    color: softText(0.04)
                    border.color: softText(0.08)
                    border.width: 1
                    implicitHeight: codeServerAccessCol.implicitHeight + 24
                    Column {
                      id: codeServerAccessCol
                      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                      anchors.margins: 12
                      spacing: 10

                      RowLayout {
                        width: parent.width
                        spacing: 10
                        Text { textFormat: Text.PlainText; text: "󰖟"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
                        ColumnLayout {
                          Layout.fillWidth: true; spacing: 2
                          Text { textFormat: Text.PlainText; text: "Access"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                          Text { textFormat: Text.PlainText; text: "How to open and sign in to Code Server."; color: softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        }
                      }

                      Rectangle { width: parent.width; height: 1; color: softText(0.08) }

                      Column {
                        width: parent.width
                        spacing: 6
                        Text { textFormat: Text.PlainText; text: "Local URL: http://localhost:" + hub.codeServerPort; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
                        Text { textFormat: Text.PlainText; text: "Tailnet: reachable via this device’s Tailnet IP/hostname on port " + hub.codeServerPort + " if the port is accessible on your network."; color: softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                        Text { textFormat: Text.PlainText; text: "Password: set in the hub during setup and stored in ~/.config/vember-code-server/code-server.env (mode 600). Config/state, persistent extensions, and uv tools are kept in ~/.config/vember-code-server (preserved on uninstall)."; color: softText(0.72); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
                      }
                    }
                  }
                }
              }
            }
          }

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
              enabled: HubModel.trimText(panel.codeServerSetupPassword).length > 0 && !hub.codeServerBusy
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
            text: removeKeyDialogCol.selectedKey ? ((HubModel.trimText(removeKeyDialogCol.selectedKey.comment || "").length > 0 ? removeKeyDialogCol.selectedKey.comment : (removeKeyDialogCol.selectedKey.type || "Key")) + " • " + (removeKeyDialogCol.selectedKey.keyPreview || "")) : ""
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
      visible: panel.updateDialogOpen
      anchors.fill: parent
      radius: card.radius
      color: Qt.rgba(0, 0, 0, 0.45)
      z: 160

      property bool busy: hub.pluginUpdateBusy || hub.updateCheckBusy
      property real progress: hub.pluginUpdateBusy ? hub.pluginUpdateProgress : (hub.updateCheckBusy ? 0 : hub.pluginUpdateProgress)
      property bool done: !hub.pluginUpdateBusy && !hub.updateCheckBusy && hub.pluginUpdateProgress >= 1 && HubModel.trimText(hub.pluginUpdateError).length === 0

      MouseArea { anchors.fill: parent; onClicked: { if (!busy) panel.updateDialogOpen = false; } }

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
            visible: HubModel.trimText(hub.pluginUpdatePun).length > 0 && (hub.pluginUpdateBusy || done)
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
            visible: HubModel.trimText(hub.pluginUpdateStatus).length > 0 || HubModel.trimText(panel.updateStatusText).length > 0
            textFormat: Text.PlainText
            text: HubModel.trimText(hub.pluginUpdateStatus).length > 0 ? hub.pluginUpdateStatus : panel.updateStatusText
            color: HubModel.trimText(hub.pluginUpdateError).length > 0 ? "#ef4444" : softText(0.85)
            font.family: Style.font.family
            wrapMode: Text.Wrap
            width: parent.width
          }

          Rectangle {
            visible: busy || hub.pluginUpdateProgress > 0 || done
            width: parent.width
            height: 10
            radius: 5
            color: softText(0.12)
            clip: true
            Rectangle {
              id: updateProgressFill
              height: parent.height
              radius: 5
              color: HubModel.trimText(hub.pluginUpdateError).length > 0 ? "#ef4444" : Color.accent
              width: progress > 0 ? (parent.width * Math.max(0, Math.min(1, progress))) : (busy ? parent.width * 0.35 : 0)
              x: (busy && progress <= 0) ? -width : 0
              Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
              SequentialAnimation on x {
                running: busy && progress <= 0 && panel.updateDialogOpen
                loops: Animation.Infinite
                NumberAnimation { from: -updateProgressFill.width; to: updateDialog.width; duration: Style.duration(1200); easing.type: Easing.InOutQuad }
              }
            }
          }

          Row {
            spacing: 8
            anchors.right: parent.right
            Button {
              text: busy ? "Updating…" : "Close"
              enabled: !busy
              onClicked: panel.updateDialogOpen = false
            }
            Button {
              visible: done
              iconText: "󰑓"
              text: "Reload"
              active: true
              onClicked: {
                panel.updateDialogOpen = false;
                hub.hotReloadHub();
              }
            }
            Button {
              visible: hub.updateAvailable && !done
              iconText: "󰚰"
              text: busy ? "Updating…" : "Update now"
              active: true
              enabled: !busy
              onClicked: {
                hub.startPluginUpdate();
              }
            }
            Button {
              visible: !hub.updateAvailable && !busy && !done
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
                hub.serverNameDraft = HubModel.trimText(hub.serverName).length > 0 ? hub.serverName : hub.defaultServerName();
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
