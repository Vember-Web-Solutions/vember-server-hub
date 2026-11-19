// Confirmation before removing the Code Server container.
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
  required property real cardRadius

  visible: panel.confirmRemoveCodeServer
  anchors.fill: parent
  radius: cardRadius
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
    border.color: panel.accentSoft(0.25)
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
        color: panel.softText(0.85)
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
          enabled: !panel.hub.codeServerBusy
          onClicked: {
            panel.confirmRemoveCodeServer = false;
            panel.hub.uninstallCodeServer();
          }
        }
      }
    }
  }
}
