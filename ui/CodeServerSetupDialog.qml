// Modal for setting the Code Server password and port.
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

  visible: panel.codeServerSetupOpen
  anchors.fill: parent
  radius: cardRadius
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
    border.color: panel.accentSoft(0.25)
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
          Text { textFormat: Text.PlainText; text: "Create the code-server Docker container, set your sign-in password/port, provision Python, uv, GitHub CLI (gh), and Python extensions, and prepare a default Python workspace in ~/Projects."; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
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
        color: panel.softText(0.03)
        border.color: panel.accentSoft(0.2)
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
        color: panel.softText(0.03)
        border.color: panel.accentSoft(0.2)
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
          text: "Cancel"
          onClicked: panel.codeServerSetupOpen = false
        }
        Button {
          iconText: "󰏔"
          text: "Set up"
          active: true
          enabled: Shell.trim(panel.codeServerSetupPassword).length > 0 && !panel.hub.codeServerBusy
          onClicked: {
            panel.codeServerSetupOpen = false;
            panel.hub.setupCodeServerTerminal(panel.codeServerSetupPassword, panel.codeServerSetupPort);
            panel.codeServerSetupPassword = "";
          }
        }
      }
    }
  }
}
