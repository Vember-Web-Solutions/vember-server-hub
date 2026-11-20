// Edit form for one hub-managed Minecraft server.
//
// Docker cannot rename or republish a container in place, so Save recreates it
// against the same /data bind. Name, port, memory, mod source and client are
// editable; loader/version/image are read back from the container and shown read-only so
// a modpack stays on the exact recipe it was created with.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "../model/Shell.mjs" as Shell
import "../model/MinecraftWizard.mjs" as Wizard

Rectangle {
  required property var panel
  required property real cardRadius

  visible: panel.confirmEditMinecraftServer
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 101

  MouseArea {
    anchors.fill: parent
    onClicked: {
      if (panel.hub.dockerBusy) return;
      panel.confirmEditMinecraftServer = false;
      panel.hub.closeMinecraftServerEditDialog();
    }
  }

  Rectangle {
    id: editMinecraftServerDialog
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 560)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
    border.width: 1
    implicitHeight: editMinecraftCol.implicitHeight + 28

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: editMinecraftCol
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 14
      spacing: 10

      RowLayout {
        width: parent.width
        spacing: 10
        Text { textFormat: Text.PlainText; text: "󰒝"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
        Text {
          textFormat: Text.PlainText
          text: "Edit " + (panel.hub.mcEditOldName || "server")
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
        text: "Docker cannot rename or republish a container in place. Saving recreates it with the same data folder, so the world and configs are kept."
        color: panel.softText(0.85)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Rectangle {
        width: parent.width
        radius: 8
        color: panel.softText(0.05)
        border.color: panel.accentSoft(0.18)
        border.width: 1
        implicitHeight: editInfoCol.implicitHeight + 18
        Column {
          id: editInfoCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 9
          spacing: 4
          Text {
            textFormat: Text.PlainText
            text: "Loaded: " + (Shell.trim(panel.hub.mcEditStatus).length > 0
              ? panel.hub.mcEditStatus : "Reading container…")
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
          Text {
            textFormat: Text.PlainText
            text: "Data folder: " + (Shell.trim(panel.hub.mcEditDataDir).length > 0
              ? panel.hub.mcEditDataDir : "Reading container…")
            color: panel.softText(0.85)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "Container name"
        color: panel.softText(0.85)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
      Rectangle {
        width: parent.width
        radius: 8
        color: panel.softText(0.03)
        border.color: panel.accentSoft(0.2)
        border.width: 1
        implicitHeight: 36
        TextInput {
          anchors.fill: parent
          anchors.margins: 9
          verticalAlignment: TextInput.AlignVCenter
          color: Color.menu.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          selectByMouse: true
          clip: true
          enabled: !panel.hub.dockerBusy
          text: panel.hub.mcEditNameDraft
          onTextChanged: panel.hub.mcEditSetName(text)
        }
      }

      RowLayout {
        width: parent.width
        spacing: 10
        Dropdown {
          Layout.fillWidth: true
          label: "Port"
          value: String(panel.hub.mcEditPortDraft)
          options: panel.hub.mcEditPortOptions
          onChanged: panel.hub.mcEditSetPort(value)
        }
        Button {
          Layout.alignment: Qt.AlignBottom
          iconText: "󰅱"
          tooltipText: "Rescan ports in use"
          enabled: !panel.hub.mcWizardPortBusy
          onClicked: panel.hub.refreshMinecraftPorts()
        }
      }
      Text {
        visible: Shell.trim(panel.hub.mcEditPortNote).length > 0
        textFormat: Text.PlainText
        text: panel.hub.mcEditPortNote
        color: panel.hub.mcWizardPortBusy ? Color.accent : panel.softText(0.75)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Dropdown {
        width: parent.width
        label: "Memory"
        value: panel.hub.mcEditMemoryDraft
        options: Wizard.memoryOptions(panel.hub.mcEditMemoryModded)
        onChanged: panel.hub.mcEditSetMemory(value)
      }
      Text {
        textFormat: Text.PlainText
        text: "Heap size for the server JVM. Saving recreates the container against the same data folder, so the world and configs are kept."
        color: panel.softText(0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Dropdown {
        width: parent.width
        label: "Join from"
        value: panel.hub.mcEditClient
        options: Wizard.clientOptions()
        onChanged: panel.hub.mcEditSetClient(value)
      }
      Text {
        textFormat: Text.PlainText
        text: "Prism auto-joins the server. The official launcher opens to the main menu with the server listed — pick it once."
        color: panel.softText(0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Dropdown {
        width: parent.width
        label: "Pull mods from Prism instance"
        value: panel.hub.mcEditModpack
        options: panel.hub.mcEditModpackOptions
        onChanged: panel.hub.mcEditChooseModpack(value)
      }
      Text {
        textFormat: Text.PlainText
        text: "Keep current mods leaves the folder untouched. Picking an instance copies its mods, plus KubeJS and config when present, into the server's data dir."
        color: panel.softText(0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Text {
        visible: Shell.trim(panel.hub.mcEditResult).length > 0
        textFormat: Text.PlainText
        text: panel.hub.mcEditResult
        color: panel.hub.mcEditResult.indexOf("failed") !== -1 ||
          panel.hub.mcEditResult.indexOf("Could not") === 0 ||
          panel.hub.mcEditResult.indexOf("may only") !== -1 ? "#ef4444" : panel.softText(0.85)
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
          enabled: !panel.hub.dockerBusy
          onClicked: {
            panel.confirmEditMinecraftServer = false;
            panel.hub.closeMinecraftServerEditDialog();
          }
        }
        Button {
          iconText: "󰌑"
          text: "Save and recreate"
          enabled: !panel.hub.dockerBusy && Shell.trim(panel.hub.mcEditNameDraft).length > 0 &&
            panel.hub.mcEditPortDraft > 0
          tooltipText: "Recreate the container with the new name and port, and refresh mods if chosen"
          onClicked: {
            // A failed validation keeps the dialog open so the message is seen;
            // a started edit closes it and reports progress on the Servers card.
            if (panel.hub.saveMinecraftServerEdit())
              panel.confirmEditMinecraftServer = false;
          }
        }
      }
    }
  }
}
