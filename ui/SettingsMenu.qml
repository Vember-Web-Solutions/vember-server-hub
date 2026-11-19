// The settings dropdown (fullscreen, arrange tabs, wizard).
//
// Extracted verbatim from HubPanel.qml. `panel` is the HubPanel root, so
// `panel.hub` is the backend and `panel.<helper>()` is a shared formatting
// helper.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons

Rectangle {
  required property var panel

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
    border.color: panel.accentSoft(0.25)
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
          panel.hub.openWizard(panel.hub.serverName || panel.hub.defaultServerName());
        }
      }
      Button {
        width: parent.width
        iconText: "󰚰"
        text: panel.hub.updateAvailable ? "Update ready" : "Check for updates"
        tooltipText: panel.hub.updateAvailable ? "A new build is available on GitHub" : "Check GitHub for a newer build"
        onClicked: {
          panel.settingsMenuOpen = false;
          if (panel.hub.updateAvailable) {
            panel.updateStatusText = panel.hub.pluginUpdateStatus || "Ready to update from GitHub.";
            panel.updateProgress = panel.hub.pluginUpdateProgress;
            panel.updateInProgress = panel.hub.pluginUpdateBusy;
            panel.updateDialogOpen = true;
          } else {
            panel.updateStatusText = "Checking for updates…";
            panel.updateProgress = 0;
            panel.updateInProgress = false;
            panel.hub.pluginUpdateProgress = 0;
            panel.hub.pluginUpdateError = "";
            panel.hub.pluginUpdatePun = "";
            panel.hub.pluginUpdateStatus = "Checking for updates…";
            panel.updateDialogOpen = true;
            panel.hub.checkPluginUpdate(true);
          }
        }
      }
    }
  }
}
