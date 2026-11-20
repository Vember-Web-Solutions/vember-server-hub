import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "model/DevTools.mjs" as DevTools
import "model/Shell.mjs" as Shell
import "model/Docker.mjs" as Docker
import "model/SystemInfo.mjs" as SystemInfo
import "model/Tailscale.mjs" as Tailscale
import "model/Config.mjs" as Config
import "ui/tabs"
import "ui"

PanelWindow {
  id: panel
  required property var hub

  property string currentTab: "overview"
  property bool confirmPrune: false
  property bool confirmApplyUpdate: false
  property string applyUpdateTarget: ""
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

  // The tab table lives in Config.mjs so it can be tested; these wrappers keep
  // the existing tabDef()/orderedTabs() call sites working.
  function tabDef(id) {
    return Config.tabDef(id);
  }

  function orderedTabs() {
    return Config.orderedTabs(hub && hub.tabOrder ? hub.tabOrder : []);
  }

  function openArrangeTabsDialog() {
    var order = (hub && hub.tabOrder && hub.tabOrder.length > 0) ? hub.tabOrder : Config.defaultTabOrder();
    panel.arrangeTabOrderDraft = order.slice(0);
    panel.settingsMenuOpen = false;
    panel.arrangeTabsOpen = true;
  }

  function moveArrangeTabDraft(index, delta) {
    panel.arrangeTabOrderDraft = Config.moveTab(panel.arrangeTabOrderDraft, index, delta);
  }

  function saveArrangeTabs() {
    hub.tabOrder = (panel.arrangeTabOrderDraft || []).slice(0);
    if (typeof hub.writeHubConfig === "function") hub.writeHubConfig(false);
    panel.arrangeTabsOpen = false;
  }

  // The panel is keepLoaded, so it survives a close instead of being destroyed
  // and rebuilt. Anything the user typed or opened would otherwise stay in
  // memory across a close/open cycle and reappear on the next open. A typed
  // Code Server password is the one that matters: it is only cleared after a
  // successful submit, so a password typed and then abandoned would sit in
  // memory for the rest of the session and be redisplayed on the next open.
  function resetTransientState() {
    panel.confirmPrune = false;
    panel.confirmApplyUpdate = false;
    panel.applyUpdateTarget = "";
    panel.confirmRemoveSshKey = false;
    panel.confirmRemoveCodeServer = false;
    panel.codeServerSetupPassword = "";
    panel.settingsMenuOpen = false;
    panel.arrangeTabsOpen = false;
  }

  onVisibleChanged: if (!visible) resetTransientState()

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
    return Docker.stateTone(state) || softText(0.5)
  }

  function dockerStateBg(state) {
    return Docker.stateBackground(state) || softText(0.08)
  }

  function storageUseColor(ratio) {
    return SystemInfo.storageUseColor(ratio)
  }

  function runningDockerCount() {
    return Docker.runningCount(hub.dockerContainers)
  }

  function onlinePeerCount() {
    return Tailscale.onlinePeerCount(hub.tailscalePeers)
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
            text: "Vember Server Hub v" + hub.pluginVersion
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
    CodeServerSetupDialog { panel: panel; cardRadius: card.radius }

    // Confirm prune popup
    PruneConfirmDialog { panel: panel; cardRadius: card.radius }

    // Confirm apply-update popup (recreate one Compose service)
    ApplyUpdateConfirmDialog { panel: panel; cardRadius: card.radius }

    // Confirm remove SSH key popup
    SshKeyConfirmDialog { panel: panel; cardRadius: card.radius }

    // Confirm remove VS Code Server container popup
    CodeServerRemoveDialog { panel: panel; cardRadius: card.radius }

    // Settings menu
    SettingsMenu { panel: panel }

    // Arrange tabs dialog
    ArrangeTabsDialog { panel: panel; cardRadius: card.radius }

    // Update dialog (GitHub build update)
    UpdateDialog { panel: panel; cardRadius: card.radius }

    // Toast notifications (stacked, bottom-right)
    ToastStack { panel: panel }

    // First-use wizard: server name
    ServerNameWizard { panel: panel; cardRadius: card.radius }
  }
}
