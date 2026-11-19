// Confirmation before `docker container prune -f`.
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

  visible: panel.confirmPrune
  anchors.fill: parent
  radius: cardRadius
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
    border.color: panel.accentSoft(0.25)
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
          onClicked: panel.confirmPrune = false
        }
        Button {
          iconText: "󰃢"
          text: panel.hub.dockerPruneBusy ? "Pruning…" : "Prune"
          enabled: !panel.hub.dockerPruneBusy
          onClicked: {
            panel.confirmPrune = false;
            panel.hub.pruneStoppedContainers();
          }
        }
      }
    }
  }
}
