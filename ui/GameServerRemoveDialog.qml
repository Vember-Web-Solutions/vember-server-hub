// Confirmation before removing one hub-detected game server.
//
// The backend command force-removes the container and deletes only its
// `<name>-data` bind mount. Prism instances and modpacks are deliberately kept.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons

Rectangle {
  required property var panel
  required property real cardRadius

  visible: panel.confirmRemoveGameServer
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 100

  MouseArea {
    anchors.fill: parent
    onClicked: {
      panel.confirmRemoveGameServer = false;
      panel.hub.closeGameServerRemoveDialog();
    }
  }

  Rectangle {
    id: removeGameServerDialog
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 520)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
    border.width: 1
    implicitHeight: removeGameServerCol.implicitHeight + 28

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: removeGameServerCol
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 14
      spacing: 12

      RowLayout {
        width: parent.width
        spacing: 10
        Text { textFormat: Text.PlainText; text: "󰆴"; color: "#ef4444"; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
        Text {
          textFormat: Text.PlainText
          text: "Remove " + (panel.hub.gameServerRemoveTarget || "server") + "?"
          color: Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.bold: true
          wrapMode: Text.Wrap
          Layout.fillWidth: true
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "This force-removes the Docker container and deletes its host data folder. The hub only accepts the matching data directory below; an unexpected mount is refused before anything is deleted. Prism instances and modpack files are kept."
        color: panel.softText(0.85)
        font.family: Style.font.family
        wrapMode: Text.Wrap
        width: parent.width
      }

      Rectangle {
        width: parent.width
        radius: 8
        color: panel.softText(0.05)
        border.color: panel.accentSoft(0.18)
        border.width: 1
        implicitHeight: targetCol.implicitHeight + 18

        Column {
          id: targetCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 9
          spacing: 4
          Text {
            textFormat: Text.PlainText
            text: "Container: " + (panel.hub.gameServerRemoveTarget || "(none)")
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
          Text {
            textFormat: Text.PlainText
            text: "Data folder to delete: " + (panel.hub.gameServerRemoveTarget || "<name>") + "-data"
            color: panel.softText(0.85)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
        }
      }

      Row {
        spacing: 8
        anchors.right: parent.right
        Button {
          text: "Cancel"
          onClicked: {
            panel.confirmRemoveGameServer = false;
            panel.hub.closeGameServerRemoveDialog();
          }
        }
        Button {
          iconText: "󰆴"
          text: "Remove server"
          enabled: !panel.hub.dockerBusy && panel.hub.gameServerRemoveTarget.length > 0
          tooltipText: "Force-remove the container and delete its matching data folder"
          onClicked: {
            panel.confirmRemoveGameServer = false;
            panel.hub.removeGameServer();
          }
        }
      }
    }
  }
}
