// First-run dialog naming the server and its role.
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

  visible: panel.hub.wizardOpen
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 120

  MouseArea { anchors.fill: parent; onClicked: {} }

  Rectangle {
    id: wizardDialog
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 520)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
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
          Text { textFormat: Text.PlainText; text: "Name this server to personalize your panel.hub."; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
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
        color: panel.softText(0.03)
        border.color: panel.accentSoft(0.2)
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
          text: panel.hub.serverNameDraft
          onTextChanged: panel.hub.serverNameDraft = text
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
        color: panel.softText(0.03)
        border.color: panel.accentSoft(0.2)
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
          text: panel.hub.serverRoleDraft
          onTextChanged: panel.hub.serverRoleDraft = text
        }
      }
      Text {
        textFormat: Text.PlainText
        text: "Examples: NAS, file server, gaming server, coding/dev server, media server, or mixed. Defaults to hostname for the name (" + panel.hub.defaultServerName() + ")."
        color: panel.softText(0.72)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Row {
        spacing: 8
        anchors.right: parent.right
        Button {
          visible: panel.hub.configReady
          text: "Cancel"
          onClicked: {
            panel.hub.serverNameDraft = Shell.trim(panel.hub.serverName).length > 0 ? panel.hub.serverName : panel.hub.defaultServerName();
            panel.hub.serverRoleDraft = panel.hub.serverRole || "";
            panel.hub.wizardOpen = false;
          }
        }
        Button {
          text: "Use hostname"
          onClicked: {
            panel.hub.serverNameDraft = panel.hub.defaultServerName();
            serverNameInput.text = panel.hub.serverNameDraft;
          }
        }
        Button {
          iconText: "󰄬"
          text: "Save"
          active: true
          onClicked: panel.hub.saveServerName(panel.hub.serverNameDraft)
        }
      }
    }
  }
}
