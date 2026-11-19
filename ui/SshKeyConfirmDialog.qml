// Confirmation before removing an authorized_keys line.
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

  visible: panel.confirmRemoveSshKey
  anchors.fill: parent
  radius: cardRadius
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
    border.color: panel.accentSoft(0.25)
    border.width: 1
    implicitHeight: removeKeyDialogCol.implicitHeight + 28

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: removeKeyDialogCol
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 14
      spacing: 12

      readonly property var selectedKey: (panel.hub.sshSelectedKeyIndex >= 0 && panel.hub.sshSelectedKeyIndex < (panel.hub.sshAuthorizedKeys ? panel.hub.sshAuthorizedKeys.length : 0)) ? panel.hub.sshAuthorizedKeys[panel.hub.sshSelectedKeyIndex] : null

      RowLayout {
        width: parent.width
        spacing: 10
        Text { textFormat: Text.PlainText; text: "󰆴"; color: "#ef4444"; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
        Text { textFormat: Text.PlainText; text: "Remove authorized key?"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true; Layout.fillWidth: true }
      }

      Text {
        textFormat: Text.PlainText
        text: "This will remove the selected key from ~/.ssh/authorized_keys. This cannot be undone."
        color: panel.softText(0.85)
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
          enabled: panel.hub.sshSelectedKeyIndex >= 0 && panel.hub.sshSelectedKeyIndex < (panel.hub.sshAuthorizedKeys ? panel.hub.sshAuthorizedKeys.length : 0)
          onClicked: {
            panel.confirmRemoveSshKey = false;
            panel.hub.removeSelectedAuthorizedKey();
          }
        }
      }
    }
  }
}
