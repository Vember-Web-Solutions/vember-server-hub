// Progress dialog for a plugin self-update.
//
// Extracted verbatim from HubPanel.qml. `panel` is the HubPanel root, so
// `panel.hub` is the backend and `panel.<helper>()` is a shared formatting
// helper.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "../model/Shell.mjs" as Shell

Rectangle {
  required property var panel
  required property real cardRadius

  id: updateDialogRoot
  visible: panel.updateDialogOpen
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 160

  property bool busy: panel.hub.pluginUpdateBusy || panel.hub.updateCheckBusy
  property real progress: panel.hub.pluginUpdateBusy ? panel.hub.pluginUpdateProgress : (panel.hub.updateCheckBusy ? 0 : panel.hub.pluginUpdateProgress)
  property bool done: !panel.hub.pluginUpdateBusy && !panel.hub.updateCheckBusy && panel.hub.pluginUpdateProgress >= 1 && Shell.trim(panel.hub.pluginUpdateError).length === 0

  MouseArea { anchors.fill: parent; onClicked: { if (!updateDialogRoot.busy) panel.updateDialogOpen = false; } }

  Rectangle {
    id: updateDialog
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 520)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
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
          Text { textFormat: Text.PlainText; text: panel.hub.updateAvailable ? "Update ready" : "Plugin update"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
          Text {
            textFormat: Text.PlainText
            text: panel.hub.updateAvailable ? ("New commits available on GitHub" + (panel.hub.pluginUpdateRemoteCommits > 0 ? (" (" + panel.hub.pluginUpdateRemoteCommits + ")") : "") + ".") : (panel.hub.updateCheckBusy ? "Checking GitHub for updates…" : "Check GitHub for a newer build.")
            color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true
          }
        }
      }

      Text {
        visible: Shell.trim(panel.hub.pluginUpdatePun).length > 0 && (panel.hub.pluginUpdateBusy || updateDialogRoot.done)
        textFormat: Text.PlainText
        text: panel.hub.pluginUpdatePun
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.italic: true
        wrapMode: Text.Wrap
        width: parent.width
      }

      Text {
        visible: Shell.trim(panel.hub.pluginUpdateStatus).length > 0 || Shell.trim(panel.updateStatusText).length > 0
        textFormat: Text.PlainText
        text: Shell.trim(panel.hub.pluginUpdateStatus).length > 0 ? panel.hub.pluginUpdateStatus : panel.updateStatusText
        color: Shell.trim(panel.hub.pluginUpdateError).length > 0 ? "#ef4444" : panel.softText(0.85)
        font.family: Style.font.family
        wrapMode: Text.Wrap
        width: parent.width
      }

      Rectangle {
        visible: updateDialogRoot.busy || panel.hub.pluginUpdateProgress > 0 || updateDialogRoot.done
        width: parent.width
        height: 10
        radius: 5
        color: panel.softText(0.12)
        clip: true
        Rectangle {
          id: updateProgressFill
          height: parent.height
          radius: 5
          color: Shell.trim(panel.hub.pluginUpdateError).length > 0 ? "#ef4444" : Color.accent
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
            panel.hub.hotReloadHub();
          }
        }
        Button {
          visible: panel.hub.updateAvailable && !updateDialogRoot.done
          iconText: "󰚰"
          text: updateDialogRoot.busy ? "Updating…" : "Update now"
          active: true
          enabled: !updateDialogRoot.busy
          onClicked: {
            panel.hub.startPluginUpdate();
          }
        }
        Button {
          visible: !panel.hub.updateAvailable && !updateDialogRoot.busy && !updateDialogRoot.done
          iconText: "󰑐"
          text: "Check again"
          onClicked: {
            panel.hub.pluginUpdateStatus = "Checking for updates…";
            panel.hub.pluginUpdateProgress = 0;
            panel.hub.pluginUpdateError = "";
            panel.hub.pluginUpdatePun = "";
            panel.hub.checkPluginUpdate(true);
          }
        }
      }
    }
  }
}
