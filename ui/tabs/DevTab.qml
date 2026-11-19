// DevTab: one tab of the Vember Server Hub panel.
//
// The tab body was moved here verbatim from HubPanel.qml. `panel` is the
// HubPanel root, so `panel.hub` is the backend and `panel.<helper>()` calls
// the shared formatting helpers.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "../../model/Shell.mjs" as Shell
import "../../model/DevTools.mjs" as DevTools

Column {
  required property var panel

  visible: panel.currentTab === "dev"
  width: parent.width
  spacing: Style.spacing.md

  // Dev sub-nav
  Row {
    spacing: 8
    Button {
      iconText: "󰊢"
      text: "Workspace"
      active: panel.devSubTab === "workspace"
      onClicked: panel.devSubTab = "workspace"
    }
    Button {
      iconText: "󰅨"
      text: "Tools"
      active: panel.devSubTab === "tools"
      onClicked: panel.devSubTab = "tools"
    }
    Button {
      iconText: hub.preferredEditor === "vscode" ? "󰨞" : "󰅱"
      text: Shell.trim(hub.preferredEditor).length > 0 ? DevTools.label(hub.preferredEditor) : "Zed"
      tooltipText: "Local editor for opening repos (click to toggle Zed / VS Code)"
      onClicked: hub.setPreferredEditor(hub.preferredEditor === "zed" ? "vscode" : "zed")
    }
    Button {
      iconText: "󰖟"
      text: "Code Server (Docker)"
      active: panel.devSubTab === "codeserver"
      onClicked: panel.devSubTab = "codeserver"
    }
  }

  Text {
    visible: Shell.trim(hub.devStatus).length > 0
    textFormat: Text.PlainText
    text: hub.devStatus
    color: panel.softText(0.78)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
    width: parent.width
  }
  Text {
    visible: Shell.trim(hub.devError).length > 0
    textFormat: Text.PlainText
    text: hub.devError
    color: "#ef4444"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
    width: parent.width
  }

  // Workspace (repos + details)
  Column {
    visible: panel.devSubTab === "workspace"
    width: parent.width
    spacing: Style.spacing.md

    RowLayout {
      width: parent.width
      spacing: 12

      // Left: repos list
      Rectangle {
        Layout.preferredWidth: Math.max(320, parent.width * 0.44)
        Layout.alignment: Qt.AlignTop
        radius: Style.cornerRadius
        color: panel.softText(0.04)
        border.color: panel.softText(0.08)
        border.width: 1
        implicitHeight: devReposCol.implicitHeight + 24
        Column {
          id: devReposCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 12
          spacing: 10

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰊢"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Repositories"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: "Select a repository to view details (size, git info) and open it in your editor."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
            Text { textFormat: Text.PlainText; text: String((hub.devRepos || []).length); color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Text {
            visible: !hub.devRepos || hub.devRepos.length === 0
            textFormat: Text.PlainText
            text: hub.devBusy ? "Scanning…" : "No repositories found in scanned locations."
            color: panel.softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: hub.devRepos || []
            delegate: Rectangle {
              required property var modelData
              width: devReposCol.width - 0
              radius: 8
              color: hub.devSelectedRepoPath === modelData.path ? panel.accentSoft(0.14) : panel.softText(0.03)
              border.color: hub.devSelectedRepoPath === modelData.path ? panel.accentSoft(0.35) : panel.softText(0.08)
              border.width: 1
              implicitHeight: repoRow.implicitHeight + 10
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: hub.selectDevRepo(modelData.path)
              }
              Column {
                id: repoRow
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 8
                spacing: 2
                Text {
                  textFormat: Text.PlainText
                  text: modelData.name || modelData.path || "repo"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.path || ""
                  color: panel.softText(0.68)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                  width: parent.width
                }
              }
            }
          }
        }
      }

      // Right: repo details
      Rectangle {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        radius: Style.cornerRadius
        color: panel.softText(0.04)
        border.color: panel.softText(0.08)
        border.width: 1
        implicitHeight: repoDetailsCol.implicitHeight + 24
        Column {
          id: repoDetailsCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 12
          spacing: 10

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰋼"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Details"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: Shell.trim(hub.devSelectedRepoPath).length > 0 ? hub.devSelectedRepoPath : "Select a repository to see its details."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Text {
            visible: Shell.trim(hub.devSelectedRepoPath).length === 0
            textFormat: Text.PlainText
            text: "No repository selected."
            color: panel.softText(0.7)
            font.family: Style.font.family
          }

          Text {
            visible: Shell.trim(hub.devSelectedRepoPath).length > 0 && hub.devRepoDetailBusy
            textFormat: Text.PlainText
            text: "Loading details…"
            color: panel.softText(0.75)
            font.family: Style.font.family
          }

          Column {
            visible: Shell.trim(hub.devSelectedRepoPath).length > 0 && !hub.devRepoDetailBusy
            width: parent.width
            spacing: 8

            GridLayout {
              width: parent.width
              columns: 2
              columnSpacing: 12
              rowSpacing: 8

              Text { textFormat: Text.PlainText; text: "Folder size"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim((hub.devRepoDetail || {}).size).length > 0 ? hub.devRepoDetail.size : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

              Text { textFormat: Text.PlainText; text: "Last modified"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim((hub.devRepoDetail || {}).mtime).length > 0 ? hub.devRepoDetail.mtime : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

              Text { textFormat: Text.PlainText; text: "Git branch"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim((hub.devRepoDetail || {}).branch).length > 0 ? hub.devRepoDetail.branch : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

              Text { textFormat: Text.PlainText; text: "Working tree"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim((hub.devRepoDetail || {}).dirty).length > 0 ? hub.devRepoDetail.dirty : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }

              Text { textFormat: Text.PlainText; text: "Remote (origin)"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim((hub.devRepoDetail || {}).remote).length > 0 ? hub.devRepoDetail.remote : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }

              Text { textFormat: Text.PlainText; text: "Last commit"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim((hub.devRepoDetail || {}).last).length > 0 ? hub.devRepoDetail.last : "—"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }

            Flow {
              width: parent.width
              spacing: 8
              Button {
                iconText: "󰏌"
                text: "Open in " + (Shell.trim(hub.preferredEditor).length > 0 ? DevTools.label(hub.preferredEditor) : "editor")
                enabled: Shell.trim(hub.devSelectedRepoPath).length > 0 && Shell.trim(hub.preferredEditor).length > 0
                tooltipText: Shell.trim(hub.preferredEditor).length > 0 ? ("Open in " + DevTools.label(hub.preferredEditor)) : "Select a preferred editor in the bar above"
                onClicked: hub.openRepoInEditor(hub.devSelectedRepoPath)
              }
              Button {
                iconText: "󰑐"
                text: "Refresh details"
                enabled: Shell.trim(hub.devSelectedRepoPath).length > 0 && !hub.devRepoDetailBusy
                onClicked: hub.selectDevRepo(hub.devSelectedRepoPath)
              }
            }
          }
        }
      }
    }
  }

  // Tools
  Column {
    visible: panel.devSubTab === "tools"
    width: parent.width
    spacing: Style.spacing.md

    // Live install log for terminal tool installs
    Rectangle {
      visible: hub.installRunningId.indexOf("dev:") === 0 && (hub.installRunning || Shell.trim(hub.installLog).length > 0)
      width: Math.min(parent.width, 720)
      radius: Style.cornerRadius
      color: panel.softText(0.04)
      border.color: hub.installRunning ? panel.accentSoft(0.30) : panel.softText(0.10)
      border.width: 1
      implicitHeight: devInstallLogCol.implicitHeight + 20
      Column {
        id: devInstallLogCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        RowLayout {
          width: parent.width
          spacing: 8
          Text { textFormat: Text.PlainText; text: "󰏔"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
          Text { Layout.fillWidth: true; textFormat: Text.PlainText; text: (Shell.trim(hub.installTitle).length > 0 ? hub.installTitle : "Install") + (hub.installRunning ? " • running" : " • log"); color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight }
          Button { visible: hub.installRunning; iconText: "󰓛"; text: "Stop"; tooltipText: "Stop tracking this install"; onClicked: hub.stopInstall() }
          Button { enabled: !hub.installRunning; iconText: "󰆴"; text: "Clear"; tooltipText: "Clear the install log"; onClicked: hub.clearInstallLog() }
        }
        Rectangle {
          width: parent.width
          height: 180
          radius: 8
          color: Qt.rgba(0, 0, 0, 0.18)
          border.color: panel.softText(0.08)
          border.width: 1
          clip: true
          Flickable {
            id: devInstallLogFlick
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: devInstallLogText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Text {
              id: devInstallLogText
              width: devInstallLogFlick.width
              textFormat: Text.PlainText
              text: Shell.trim(hub.installLog).length > 0 ? hub.installLog : "Waiting for output…"
              color: Shell.trim(hub.installLog).length > 0 ? panel.softText(0.92) : panel.softText(0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WrapAnywhere
            }
            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
          }
        }
      }
    }

    Rectangle {
      width: Math.min(parent.width, 720)
      radius: Style.cornerRadius
      color: panel.softText(0.04)
      border.color: panel.softText(0.08)
      border.width: 1
      implicitHeight: devToolsCol.implicitHeight + 24
      Column {
        id: devToolsCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        RowLayout {
          width: parent.width
          spacing: 10
          Text { textFormat: Text.PlainText; text: "󰅨"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
          ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { textFormat: Text.PlainText; text: "Tools"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { textFormat: Text.PlainText; text: "Toolchain and editor installs for this server."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
        }

        Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

        Repeater {
          model: hub.devTools || []
          delegate: Rectangle {
            required property var modelData
            width: devToolsCol.width - 0
            radius: 8
            color: panel.softText(0.03)
            border.color: panel.softText(0.08)
            border.width: 1
            implicitHeight: toolRow.implicitHeight + 12
            RowLayout {
              id: toolRow
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 8
              spacing: 8
              Rectangle {
                width: 10; height: 10; radius: 5
                color: modelData.installed ? "#22c55e" : panel.softText(0.35)
                Layout.alignment: Qt.AlignVCenter
              }
              Column {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  textFormat: Text.PlainText
                  text: DevTools.label(modelData.id)
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData.installed ? (Shell.trim(modelData.version).length > 0 ? modelData.version : (modelData.path || "Installed")) : "Not installed"
                  color: modelData.installed ? panel.softText(0.78) : panel.softText(0.65)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  wrapMode: Text.NoWrap
                  width: parent.width
                }
                Text {
                  visible: modelData.installed && Shell.trim(modelData.path).length > 0
                  textFormat: Text.PlainText
                  text: modelData.path
                  color: panel.softText(0.6)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                  width: parent.width
                }
              }
              Column {
                visible: !modelData.installed
                spacing: 4
                Layout.alignment: Qt.AlignVCenter
                Row {
                  spacing: 6
                  Button {
                    iconText: "󰏔"
                    text: (hub.devInstallBusy && hub.devInstallToolId === modelData.id) ? "Installing…" : "Install"
                    tooltipText: "Try silent install for " + DevTools.label(modelData.id)
                    enabled: !hub.devInstallBusy && !hub.installRunning
                    onClicked: hub.runDevInstallSilent(modelData.id)
                  }
                  Button {
                    iconText: "󰆍"
                    text: (hub.installRunning && hub.installRunningId === ("dev:" + modelData.id)) ? "Installing…" : "Terminal"
                    tooltipText: "Open the default terminal to install " + DevTools.label(modelData.id)
                    enabled: !hub.devInstallBusy && !hub.installRunning
                    onClicked: hub.openDevInstallTerminal(modelData.id)
                  }
                }
                Text {
                  visible: hub.devInstallBusy && hub.devInstallToolId === modelData.id
                  textFormat: Text.PlainText
                  text: "Running…"
                  color: panel.softText(0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
              Text {
                visible: modelData.installed
                textFormat: Text.PlainText
                text: "Installed"
                color: "#22c55e"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }

  // Code Server (Docker) mapped view
  Column {
    visible: panel.devSubTab === "codeserver"
    width: parent.width
    spacing: Style.spacing.md

    RowLayout {
      width: parent.width
      spacing: 12

      // Status & actions
      Rectangle {
        Layout.preferredWidth: Math.max(320, parent.width * 0.46)
        Layout.alignment: Qt.AlignTop
        radius: Style.cornerRadius
        color: panel.softText(0.04)
        border.color: panel.accentSoft(hub.codeServerRunning ? 0.28 : 0.14)
        border.width: 1
        implicitHeight: codeServerStatusCol.implicitHeight + 24
        Column {
          id: codeServerStatusCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 12
          spacing: 10

          RowLayout {
            width: parent.width
            spacing: 10
            Text { textFormat: Text.PlainText; text: "󰨞"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "VS Code Server"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: "Browser-based editor in Docker (code-server)"; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
            Rectangle {
              radius: 10
              color: hub.codeServerRunning ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : panel.softText(0.1)
              border.color: hub.codeServerRunning ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
              border.width: hub.codeServerRunning ? 1 : 0
              implicitWidth: codeServerBadge2.implicitWidth + 14
              implicitHeight: codeServerBadge2.implicitHeight + 8
              Text {
                id: codeServerBadge2
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: hub.codeServerPresent ? hub.codeServerState : "not set up"
                color: hub.codeServerRunning ? "#22c55e" : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: hub.codeServerRunning
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Text {
            visible: Shell.trim(hub.codeServerStatusText).length > 0
            textFormat: Text.PlainText
            text: hub.codeServerStatusText
            color: panel.softText(0.82)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          Column {
            visible: hub.codeServerBusy || hub.codeServerSetupStage === "preparing" || hub.codeServerSetupStage === "pulling" || hub.codeServerSetupStage === "creating" || hub.codeServerSetupStage === "starting" || hub.codeServerSetupStage === "provisioning" || hub.codeServerSetupStage === "running" || hub.codeServerSetupStage === "launching" || hub.codeServerSetupStage === "checking" || hub.codeServerSetupStage === "error" || hub.codeServerSetupStage === "exists" || hub.codeServerSetupStage === "done"
            width: parent.width
            spacing: 6

            Text {
              textFormat: Text.PlainText
              text: Shell.trim(hub.codeServerSetupDetail).length > 0 ? hub.codeServerSetupDetail : "Setting up VS Code Server…"
              color: hub.codeServerSetupStage === "error" ? "#ef4444" : panel.softText(0.82)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }

            Text {
              visible: hub.codeServerSetupBytesTotal > 0
              textFormat: Text.PlainText
              text: Shell.humanBytes(hub.codeServerSetupBytesDone) + " / " + Shell.humanBytes(hub.codeServerSetupBytesTotal) + " (" + Math.round(Math.max(0, Math.min(1, hub.codeServerSetupProgress)) * 100) + "%)"
              color: panel.softText(0.75)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }

            Rectangle {
              visible: hub.codeServerBusy || hub.codeServerSetupStage === "pulling" || hub.codeServerSetupStage === "creating" || hub.codeServerSetupStage === "starting" || hub.codeServerSetupStage === "preparing" || hub.codeServerSetupStage === "provisioning"
              width: parent.width
              height: 8
              radius: 4
              color: panel.softText(0.12)
              clip: true
              Rectangle {
                id: codeServerSetupProgressFill
                height: parent.height
                radius: 4
                color: hub.codeServerSetupStage === "error" ? "#ef4444" : Color.accent
                width: hub.codeServerSetupProgress > 0 ? (parent.width * Math.max(0, Math.min(1, hub.codeServerSetupProgress))) : (parent.width * 0.35)
                x: hub.codeServerSetupProgress > 0 ? 0 : -width
                Behavior on width { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
                SequentialAnimation on x {
                  running: (hub.codeServerSetupProgress <= 0) && (hub.codeServerBusy || hub.codeServerSetupStage === "preparing" || hub.codeServerSetupStage === "pulling" || hub.codeServerSetupStage === "creating" || hub.codeServerSetupStage === "starting" || hub.codeServerSetupStage === "provisioning")
                  loops: Animation.Infinite
                  NumberAnimation { from: -codeServerSetupProgressFill.width; to: codeServerSetupProgressFill.parent ? codeServerSetupProgressFill.parent.width : 300; duration: Style.duration(1200); easing.type: Easing.InOutQuad }
                }
              }
            }

            Rectangle {
              visible: Shell.trim(hub.codeServerSetupLog).length > 0
              width: parent.width
              radius: 8
              color: panel.softText(0.03)
              border.color: panel.softText(0.08)
              border.width: 1
              implicitHeight: Math.min(180, setupLogText.implicitHeight + 16)
              clip: true

              Flickable {
                id: setupLogFlick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: setupLogText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Text {
                  id: setupLogText
                  width: setupLogFlick.width
                  textFormat: Text.PlainText
                  text: hub.codeServerSetupLog
                  color: panel.softText(0.78)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WrapAnywhere
                }
                onContentHeightChanged: {
                  if (contentHeight > height) contentY = contentHeight - height;
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: 4
            Text { textFormat: Text.PlainText; text: "Actions"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
            Flow {
              width: parent.width
              spacing: 8
              Button {
                visible: !hub.codeServerPresent
                iconText: "󰏔"
                text: hub.codeServerBusy ? "Working…" : "Set up"
                tooltipText: "Configure and create the VS Code Server container"
                enabled: !hub.codeServerBusy
                active: true
                onClicked: {
                  panel.codeServerSetupPassword = "";
                  panel.codeServerSetupPort = String(hub.codeServerPort || 8443);
                  panel.codeServerSetupOpen = true;
                }
              }
              Button {
                visible: hub.codeServerPresent && !hub.codeServerRunning
                iconText: "󰐊"
                text: "Start"
                enabled: !hub.codeServerBusy
                onClicked: hub.startCodeServer()
              }
              Button {
                visible: hub.codeServerPresent && hub.codeServerRunning
                iconText: "󰓛"
                text: "Stop"
                enabled: !hub.codeServerBusy
                onClicked: hub.stopCodeServer()
              }
              Button {
                visible: hub.codeServerPresent
                iconText: "󰖟"
                text: "Open in browser"
                tooltipText: "Open VS Code Server in browser"
                enabled: hub.codeServerRunning
                active: hub.codeServerRunning
                onClicked: hub.openCodeServer()
              }
              Button {
                iconText: "󰑐"
                text: "Refresh"
                tooltipText: "Refresh VS Code Server container status"
                enabled: !hub.codeServerBusy
                onClicked: hub.refreshCodeServer()
              }
              Button {
                visible: hub.codeServerPresent
                iconText: "󰆴"
                text: "Uninstall"
                tooltipText: "Remove the VS Code Server container"
                enabled: !hub.codeServerBusy
                onClicked: panel.confirmRemoveCodeServer = true
              }
            }
          }

          Text {
            visible: !hub.codeServerPresent
            textFormat: Text.PlainText
            text: "Set a password and port in the hub. Setup creates the container, installs Python, uv, and GitHub CLI (gh), installs Python extensions (ms-python.python, ms-python.debugpy, charliermarsh.ruff), and prepares a default Python workspace in ~/Projects. Progress and debug logs are shown in the panel. Password is stored in a restricted env file (not in config.yaml)."
            color: panel.softText(0.72)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
        }
      }

      // Map/details
      Column {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 12

        Rectangle {
          width: parent.width
          radius: Style.cornerRadius
          color: panel.softText(0.04)
          border.color: panel.softText(0.08)
          border.width: 1
          implicitHeight: codeServerMapCol.implicitHeight + 24
          Column {
            id: codeServerMapCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
              width: parent.width
              spacing: 10
              Text { textFormat: Text.PlainText; text: "󰘦"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { textFormat: Text.PlainText; text: "Docker map"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { textFormat: Text.PlainText; text: "How the VS Code Server container is set up on this machine."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
              }
            }

            Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

            GridLayout {
              width: parent.width
              columns: 2
              columnSpacing: 12
              rowSpacing: 8

              Text { textFormat: Text.PlainText; text: "Container"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "vember-code-server"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Image"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: Shell.trim(hub.codeServerImage).length > 0 ? hub.codeServerImage : "codercom/code-server:latest"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Port"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "localhost:" + hub.codeServerPort + " → container:8080"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Home mount"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "$HOME → /home/coder/home"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Config"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "~/.config/vember-code-server → /home/coder/.config"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "User data"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "~/.config/vember-code-server/user-data → /home/coder/.local/share/code-server (extensions/settings)"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Tools bin"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "~/.config/vember-code-server/bin → /home/coder/.local/bin (uv/uvx)"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Default open"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "No folder (open a project when needed)"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true; wrapMode: Text.Wrap }

              Text { textFormat: Text.PlainText; text: "Restart"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "unless-stopped"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; Layout.fillWidth: true }
            }
          }
        }

        Rectangle {
          width: parent.width
          radius: Style.cornerRadius
          color: panel.softText(0.04)
          border.color: panel.softText(0.08)
          border.width: 1
          implicitHeight: codeServerAccessCol.implicitHeight + 24
          Column {
            id: codeServerAccessCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
              width: parent.width
              spacing: 10
              Text { textFormat: Text.PlainText; text: "󰖟"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { textFormat: Text.PlainText; text: "Access"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                Text { textFormat: Text.PlainText; text: "How to open and sign in to Code Server."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
              }
            }

            Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

            Column {
              width: parent.width
              spacing: 6
              Text { textFormat: Text.PlainText; text: "Local URL: http://localhost:" + hub.codeServerPort; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
              Text { textFormat: Text.PlainText; text: "Tailnet: reachable via this device’s Tailnet IP/hostname on port " + hub.codeServerPort + " if the port is accessible on your network."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
              Text { textFormat: Text.PlainText; text: "Password: set in the hub during setup and stored in ~/.config/vember-code-server/code-server.env (mode 600). Config/state, persistent extensions, and uv tools are kept in ~/.config/vember-code-server (preserved on uninstall)."; color: panel.softText(0.72); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
            }
          }
        }
      }
    }
  }
}
