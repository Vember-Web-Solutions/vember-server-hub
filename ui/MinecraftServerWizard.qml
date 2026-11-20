// Guided Minecraft server creation: client → runtime → options → review.
//
// Modal like the VS Code Server setup. `panel` is the HubPanel root, so the
// backend is `panel.hub`. All option lists and install commands come from
// MinecraftWizard.mjs — this file only lays them out.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "../model/MinecraftWizard.mjs" as Wizard
import "../model/Shell.mjs" as Shell

Rectangle {
  required property var panel
  required property real cardRadius

  visible: panel.hub.mcWizardOpen
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 120

  MouseArea {
    anchors.fill: parent
    onClicked: panel.hub.closeMinecraftServerWizard()
  }

  Rectangle {
    id: wizardCard
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 640)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
    border.width: 1
    implicitHeight: wizardCol.implicitHeight + 28

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: wizardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 14
      spacing: 12

      // Header
      RowLayout {
        width: parent.width
        spacing: 10
        Text {
          textFormat: Text.PlainText
          text: "󰍳"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.iconLarge
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            textFormat: Text.PlainText
            text: "Create a Minecraft server"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: "Four quick steps — pick a client, prepare Docker, choose the options, review."
            color: panel.softText(0.8)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }
        }
        Button {
          iconText: "󰅖"
          tooltipText: "Close the wizard"
          onClicked: panel.hub.closeMinecraftServerWizard()
        }
      }

      // Step indicator
      RowLayout {
        width: parent.width
        spacing: 6
        Repeater {
          model: [1, 2, 3, 4]
          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: 26
            radius: 6
            color: panel.hub.mcWizardStep >= modelData ? panel.accentSoft(0.35) : panel.softText(0.06)
            border.color: panel.hub.mcWizardStep === modelData ? Color.accent : panel.accentSoft(0.15)
            border.width: panel.hub.mcWizardStep === modelData ? 2 : 1
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: ["Client", "Runtime", "Options", "Review"][modelData - 1]
              color: panel.hub.mcWizardStep >= modelData ? Color.menu.text : panel.softText(0.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: panel.hub.mcWizardStep === modelData
            }
          }
        }
      }

      // --- Step 1: client ---
      Column {
        width: parent.width
        visible: panel.hub.mcWizardStep === 1
        spacing: 8
        Text {
          textFormat: Text.PlainText
          text: "Which launcher will you use to join?"
          color: Color.menu.text
          font.family: Style.font.family
          font.bold: true
        }
        Repeater {
          model: Wizard.clientOptions()
          delegate: Rectangle {
            width: parent.width
            implicitHeight: 54
            radius: 8
            property bool selected: panel.hub.mcWizardClient === modelData.value
            property bool installed: panel.hub.mcWizardClientInstalled[modelData.value] === true
            color: selected ? panel.accentSoft(0.16) : panel.softText(0.03)
            border.color: selected ? Color.accent : panel.accentSoft(0.2)
            border.width: 1
            MouseArea {
              anchors.fill: parent
              onClicked: panel.hub.mcWizardClient = modelData.value
            }
            RowLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 10
              Text {
                textFormat: Text.PlainText
                text: selected ? "󰅯" : "󰄐"
                color: selected ? Color.accent : panel.softText(0.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.detail
                  color: panel.softText(0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                  Layout.fillWidth: true
                }
              }
              Text {
                textFormat: Text.PlainText
                text: installed ? "Installed" : "Not installed"
                color: installed ? "#4ade80" : panel.softText(0.6)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
        Text {
          textFormat: Text.PlainText
          text: panel.hub.mcWizardClientInstalled[panel.hub.mcWizardClient] === true
            ? ("Ready to join at " + panel.hub.mcWizardJoinAddress)
            : (Wizard.clientName(panel.hub.mcWizardClient) + " was not detected. Install it to join the server.")
          color: panel.softText(0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
        Button {
          visible: panel.hub.mcWizardClientInstalled[panel.hub.mcWizardClient] !== true
          enabled: !panel.hub.mcWizardInstallBusy
          iconText: "󰏔"
          text: panel.hub.mcWizardInstallBusy ? "Installing…" : ("Install " + Wizard.clientName(panel.hub.mcWizardClient))
          onClicked: panel.hub.mcWizardInstallClient()
        }
        Text {
          visible: Shell.trim(panel.hub.mcWizardInstallStatus).length > 0
          textFormat: Text.PlainText
          text: panel.hub.mcWizardInstallStatus
          color: panel.softText(0.75)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
      }

      // --- Step 2: runtime ---
      Column {
        width: parent.width
        visible: panel.hub.mcWizardStep === 2
        spacing: 8
        Text {
          textFormat: Text.PlainText
          text: "How should the server run?"
          color: Color.menu.text
          font.family: Style.font.family
          font.bold: true
        }
        Repeater {
          model: Wizard.runModeOptions()
          delegate: Rectangle {
            width: parent.width
            implicitHeight: 54
            radius: 8
            property bool selected: panel.hub.mcWizardRunMode === modelData.value
            color: selected ? panel.accentSoft(0.16) : panel.softText(0.03)
            border.color: selected ? Color.accent : panel.accentSoft(0.2)
            border.width: 1
            MouseArea {
              anchors.fill: parent
              onClicked: panel.hub.mcWizardRunMode = modelData.value
            }
            RowLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 10
              Text {
                textFormat: Text.PlainText
                text: selected ? "󰅯" : "󰄐"
                color: selected ? Color.accent : panel.softText(0.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText
                  text: modelData.label
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.detail
                  color: panel.softText(0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                  Layout.fillWidth: true
                }
              }
            }
          }
        }

        // Docker route: check daemon, then image, then pull with live progress.
        Column {
          width: parent.width
          visible: panel.hub.mcWizardRunMode === "docker"
          spacing: 8
          Text {
            textFormat: Text.PlainText
            text: panel.hub.mcWizardCheckText
            color: panel.hub.mcWizardDockerReady === "missing" ? "#ef4444" : panel.softText(0.85)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
          Row {
            spacing: 8
            Button {
              visible: !panel.hub.mcWizardImageReady && !panel.hub.mcWizardPullBusy
              enabled: panel.hub.mcWizardDockerReady === "ready"
              iconText: "󰏔"
              text: "Pull image"
              onClicked: panel.hub.mcWizardPullImage()
            }
            Button {
              visible: panel.hub.mcWizardPullBusy
              iconText: "󰓛"
              text: "Stop pull"
              onClicked: panel.hub.mcWizardCancelPull()
            }
          }
          Text {
            visible: Shell.trim(panel.hub.mcWizardPullStatus).length > 0
            textFormat: Text.PlainText
            text: panel.hub.mcWizardPullStatus
            color: panel.softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
          Rectangle {
            visible: panel.hub.mcWizardPullBusy || panel.hub.mcWizardImageReady
            width: parent.width
            height: 8
            radius: 4
            color: panel.softText(0.12)
            clip: true
            Rectangle {
              height: parent.height
              radius: 4
              color: Color.accent
              width: panel.hub.mcWizardPullPercent > 0
                ? parent.width * Math.max(0, Math.min(1, panel.hub.mcWizardPullPercent))
                : (panel.hub.mcWizardImageReady ? parent.width : parent.width * 0.35)
            }
          }
        }

        // Manual route: no daemon needed, just the command to run by hand.
        Column {
          width: parent.width
          visible: panel.hub.mcWizardRunMode === "manual"
          spacing: 6
          Text {
            textFormat: Text.PlainText
            text: "Run this on the Docker host, then join at " + panel.hub.mcWizardJoinAddress + ":"
            color: panel.softText(0.8)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
          Rectangle {
            width: parent.width
            radius: 8
            color: panel.softText(0.03)
            border.color: panel.accentSoft(0.2)
            border.width: 1
            implicitHeight: cmdText.implicitHeight + 20
            Text {
              id: cmdText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 10
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: panel.hub.mcWizardCommandPreview()
              color: Color.menu.text
              font.family: "monospace"
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
          }
        }
      }

      // --- Step 3: options ---
      Column {
        width: parent.width
        visible: panel.hub.mcWizardStep === 3
        spacing: 10
        Text {
          textFormat: Text.PlainText
          text: "Choose the server options"
          color: Color.menu.text
          font.family: Style.font.family
          font.bold: true
        }
        Dropdown {
          width: parent.width
          label: "Installed modpack"
          value: panel.hub.mcWizardModpack
          options: panel.hub.mcWizardModpackOptions
          onChanged: panel.hub.mcWizardChooseModpack(value)
        }
        Text {
          visible: Shell.trim(panel.hub.mcWizardModsDir).length > 0
          textFormat: Text.PlainText
          text: "Loaded from this modpack: " + panel.hub.mcServerTypeDraft + " " +
            panel.hub.mcServerVersionDraft + (Shell.trim(panel.hub.mcWizardWorldDir).length > 0
              ? " with its world save" : " with its mods")
          color: panel.softText(0.75)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
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
            text: panel.hub.mcServerNameDraft
            onTextChanged: panel.hub.mcWizardNameChanged(text)
          }
        }
        RowLayout {
          width: parent.width
          spacing: 10
          Dropdown {
            Layout.fillWidth: true
            label: "Server type"
            value: panel.hub.mcServerTypeDraft
            options: Wizard.serverTypeOptions()
            onChanged: panel.hub.mcWizardSetType(value)
          }
          Dropdown {
            Layout.fillWidth: true
            label: "Version"
            value: panel.hub.mcServerVersionDraft
            options: Wizard.versionOptions()
            onChanged: panel.hub.mcServerVersionDraft = value
          }
        }
        RowLayout {
          width: parent.width
          spacing: 10
          Dropdown {
            Layout.fillWidth: true
            label: "Memory"
            value: panel.hub.mcServerMemoryDraft
            options: Wizard.memoryOptions(Wizard.isModdedType(panel.hub.mcServerTypeDraft))
            onChanged: panel.hub.mcServerMemoryDraft = value
          }
          Dropdown {
            Layout.fillWidth: true
            label: "Difficulty"
            value: panel.hub.mcServerDifficultyDraft
            options: Wizard.difficultyOptions()
            onChanged: panel.hub.mcServerDifficultyDraft = value
          }
        }
        RowLayout {
          width: parent.width
          spacing: 10
          Dropdown {
            Layout.fillWidth: true
            label: "Port"
            value: String(panel.hub.mcServerPortDraft)
            options: panel.hub.mcWizardPortOptions
            onChanged: panel.hub.mcWizardSetPort(value)
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
          visible: Shell.trim(panel.hub.mcWizardPortNote).length > 0
          textFormat: Text.PlainText
          text: panel.hub.mcWizardPortNote
          color: panel.hub.mcWizardPortBusy ? Color.accent : panel.softText(0.75)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
        Text {
          textFormat: Text.PlainText
          text: "World data directory"
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
            text: panel.hub.mcServerDataDirDraft
            onTextEdited: {
              panel.hub.mcServerDataDirDraft = text;
              panel.hub.mcServerDataDirAutoName = "";
            }
          }
        }
      }

      // --- Step 4: review ---
      Column {
        width: parent.width
        visible: panel.hub.mcWizardStep === 4
        spacing: 10
        Text {
          textFormat: Text.PlainText
          text: panel.hub.mcWizardRunMode === "docker"
            ? "Review, then create the container"
            : "You're all set"
          color: Color.menu.text
          font.family: Style.font.family
          font.bold: true
        }
        Rectangle {
          width: parent.width
          radius: 8
          color: panel.accentSoft(0.12)
          border.color: panel.accentSoft(0.3)
          border.width: 1
          implicitHeight: reviewCol.implicitHeight + 20
          Column {
            id: reviewCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
              textFormat: Text.PlainText
              text: panel.hub.mcServerTypeDraft + " " + panel.hub.mcServerVersionDraft +
                " · " + panel.hub.mcServerMemoryDraft + " RAM · " + panel.hub.mcServerDifficultyDraft
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              wrapMode: Text.Wrap
              width: parent.width
            }
            Text {
              textFormat: Text.PlainText
              text: "Join at " + panel.hub.mcWizardJoinAddress + " with " +
                Wizard.clientName(panel.hub.mcWizardClient)
              color: panel.softText(0.85)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }
            Text {
              visible: Shell.trim(panel.hub.mcWizardSupportDir).length > 0
              textFormat: Text.PlainText
              text: "Includes the modpack's mods, world and KubeJS config."
              color: panel.softText(0.85)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }
          }
        }
        Rectangle {
          visible: panel.hub.mcWizardRunMode === "docker" && Shell.trim(panel.hub.mcWizardCommandPreview()).length > 0
          width: parent.width
          radius: 8
          color: panel.softText(0.03)
          border.color: panel.accentSoft(0.2)
          border.width: 1
          implicitHeight: previewText.implicitHeight + 20
          Text {
            id: previewText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: panel.hub.mcWizardCommandPreview()
            color: panel.softText(0.8)
            font.family: "monospace"
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }
        Text {
          visible: Shell.trim(panel.hub.mcServerCreateStatus).length > 0
          textFormat: Text.PlainText
          text: panel.hub.mcServerCreateStatus
          color: panel.hub.mcServerCreateBusy ? Color.accent : panel.softText(0.85)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
        Text {
          visible: Shell.trim(panel.hub.mcServerCreateResult).length > 0
          textFormat: Text.PlainText
          text: panel.hub.mcServerCreateResult
          color: panel.hub.mcServerCreateResult.indexOf("failed") !== -1 ? "#ef4444" : panel.softText(0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
        Button {
          visible: Shell.trim(panel.hub.mcServerLaunchName).length > 0
          enabled: !panel.hub.mcServerLaunchBusy
          iconText: "󰐊"
          text: panel.hub.mcServerLaunchBusy ? "Launching…" : ("Launch " + panel.hub.mcServerLaunchName)
          tooltipText: "Start the container and open Prism joined to this server"
          onClicked: panel.hub.launchMinecraftServer(
            panel.hub.mcServerLaunchName, panel.hub.mcServerLaunchPort,
            panel.hub.mcServerLaunchSource)
        }
        Text {
          visible: Shell.trim(panel.hub.mcServerLaunchStatus).length > 0
          textFormat: Text.PlainText
          text: panel.hub.mcServerLaunchStatus
          color: panel.softText(0.8)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
      }

      // Footer
      Row {
        anchors.right: parent.right
        spacing: 8
        Button {
          text: "Cancel"
          enabled: !panel.hub.mcServerCreateBusy
          onClicked: panel.hub.closeMinecraftServerWizard()
        }
        Button {
          visible: panel.hub.mcWizardStep > 1
          iconText: "󰅁"
          text: "Back"
          enabled: !panel.hub.mcServerCreateBusy
          onClicked: panel.hub.mcWizardBack()
        }
        Button {
          visible: panel.hub.mcWizardStep < 4
          iconText: "󰅂"
          text: "Next"
          enabled: panel.hub.mcWizardRunMode === "manual" ||
            panel.hub.mcWizardDockerReady !== "missing"
          onClicked: panel.hub.mcWizardNext()
        }
        Button {
          visible: panel.hub.mcWizardStep === 4 && panel.hub.mcWizardRunMode === "docker"
          enabled: !panel.hub.mcServerCreateBusy && panel.hub.mcWizardImageReady
          iconText: "󰏔"
          text: panel.hub.mcServerCreateBusy ? "Creating…" : "Create server"
          onClicked: panel.hub.mcWizardCreate()
        }
        Button {
          visible: panel.hub.mcWizardStep === 4 && panel.hub.mcWizardRunMode === "manual"
          iconText: "󰄬"
          text: "Done"
          active: true
          onClicked: panel.hub.closeMinecraftServerWizard()
        }
      }
    }
  }
}
