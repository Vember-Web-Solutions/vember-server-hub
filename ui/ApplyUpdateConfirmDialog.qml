// Confirmation before recreating a Compose service to apply a pulled image.
//
// The target container's name is held on the HubPanel as `applyUpdateTarget`.
// Confirming calls into the backend, which re-reads the container's Compose
// labels and recreates only that service with `up -d --no-deps`.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons

Rectangle {
  required property var panel
  required property real cardRadius

  visible: panel.confirmApplyUpdate
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 101

  MouseArea {
    anchors.fill: parent
    onClicked: panel.confirmApplyUpdate = false
  }

  Rectangle {
    id: applyDialog
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 480)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
    border.width: 1
    implicitHeight: applyDialogCol.implicitHeight + 28

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: applyDialogCol
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 14
      spacing: 12

      RowLayout {
        width: parent.width
        spacing: 10
        Text { textFormat: Text.PlainText; text: "󰓯"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
        Text { textFormat: Text.PlainText; text: "Apply image update?"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; Layout.fillWidth: true }
      }

      Text {
        textFormat: Text.PlainText
        text: "Recreate “" + panel.applyUpdateTarget + "” from its Compose file so it runs the pulled image. The service will be briefly unavailable; its data volumes are not touched. Dependent services stay running."
        color: panel.softText(0.85)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
        width: parent.width
      }

      Row {
        spacing: 8
        anchors.right: parent.right
        Button {
          text: "Cancel"
          onClicked: panel.confirmApplyUpdate = false
        }
        Button {
          iconText: "󰓯"
          text: panel.hub.dockerBusy ? "Applying…" : "Apply update"
          enabled: !panel.hub.dockerBusy
          onClicked: {
            panel.confirmApplyUpdate = false;
            panel.hub.startApplyComposeUpdate(panel.applyUpdateTarget);
          }
        }
      }
    }
  }
}
