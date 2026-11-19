// OverviewTab: one tab of the Vember Server Hub panel.
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

  visible: panel.currentTab === "overview"
  width: parent.width
  spacing: Style.spacing.md

  Row {
    spacing: 8
    Button {
      iconText: "󰋜"
      text: "Overview"
      active: panel.overviewSubTab === "overview"
      onClicked: panel.overviewSubTab = "overview"
    }
    Button {
      iconText: "󰚰"
      text: "Update"
      active: panel.overviewSubTab === "update"
      onClicked: panel.overviewSubTab = "update"
    }
  }

  Column {
    visible: panel.overviewSubTab === "overview"
    width: parent.width
    spacing: Style.spacing.lg

    // Hero / server summary
    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.accentSoft(0.08)
      border.color: panel.accentSoft(0.20)
      border.width: 1
      implicitHeight: heroCol.implicitHeight + 28
      Column {
        id: heroCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        RowLayout {
          width: parent.width
          spacing: 14
          Text {
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            text: "󰒋"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Math.round(Style.font.iconLarge * 1.5)
          }
          Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            text: hub.defaultServerName()
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Math.round(Style.font.heading * 1.4)
            font.bold: true
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "Use the tabs to check access, manage containers, open repositories, and monitor gaming and storage on this server."
          color: panel.softText(0.78)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }

        Flow {
          width: parent.width
          spacing: 8
          Rectangle {
            radius: 10
            color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : panel.softText(0.1)
            border.color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
            border.width: hub.tailscaleActive === "active" ? 1 : 0
            implicitWidth: heroTsChip.implicitWidth + 14
            implicitHeight: heroTsChip.implicitHeight + 8
            Text {
              id: heroTsChip
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "Tailnet: " + hub.tailscaleActive
              color: hub.tailscaleActive === "active" ? "#22c55e" : Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: hub.tailscaleActive === "active"
            }
          }
          Rectangle {
            radius: 10
            color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : panel.softText(0.1)
            border.color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
            border.width: hub.sshActive === "active" ? 1 : 0
            implicitWidth: heroSshChip.implicitWidth + 14
            implicitHeight: heroSshChip.implicitHeight + 8
            Text {
              id: heroSshChip
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "SSH: " + hub.sshActive
              color: hub.sshActive === "active" ? "#22c55e" : Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: hub.sshActive === "active"
            }
          }
        }
      }
    }

    Column {
      width: parent.width
      spacing: Style.spacing.sm

      Text {
        textFormat: Text.PlainText
        text: "At a glance"
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.heading
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        text: "Open a card for details and controls."
        color: panel.softText(0.72)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Flow {
      width: parent.width
      spacing: 14

      // Access glance
      Rectangle {
        width: 320
        radius: 14
        color: panel.softText(0.045)
        border.color: hub.tailscaleActive === "active" ? panel.accentSoft(0.35) : panel.softText(0.10)
        border.width: 1
        implicitHeight: glanceTs.implicitHeight + 24
        MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "access" }
        Column {
          id: glanceTs
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14; spacing: 10
          RowLayout {
            width: parent.width; spacing: 10
            Text { textFormat: Text.PlainText; text: "󰖂"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Access"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text {
                textFormat: Text.PlainText
                text: Shell.trim(hub.tailscaleTailnetName).length > 0 ? hub.tailscaleTailnetName : (Shell.trim(hub.serverName).length > 0 ? hub.serverName : hub.defaultServerName())
                color: panel.softText(0.78)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
            Rectangle {
              radius: 10
              color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : panel.softText(0.1)
              border.color: hub.tailscaleActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
              border.width: hub.tailscaleActive === "active" ? 1 : 0
              implicitWidth: glanceTsBadge.implicitWidth + 14
              implicitHeight: glanceTsBadge.implicitHeight + 8
              Text {
                id: glanceTsBadge
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: hub.tailscaleActive
                color: hub.tailscaleActive === "active" ? "#22c55e" : Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: hub.tailscaleActive === "active"
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Column {
            width: parent.width
            spacing: 6
            Text { textFormat: Text.PlainText; text: "Peers: " + panel.onlinePeerCount() + " online / " + hub.tailscalePeers.length + " total"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
            Text { visible: Shell.trim(hub.tailscaleIp).length > 0; textFormat: Text.PlainText; text: "Tailnet IP: " + hub.tailscaleIp; color: panel.softText(0.82); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
            Text { textFormat: Text.PlainText; text: "SSH " + hub.sshActive + " • tailscaled " + hub.tailscaleEnabled; color: panel.softText(0.72); font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }

          Text { textFormat: Text.PlainText; text: "Open Access tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // Containers glance
      Rectangle {
        width: 320
        radius: 14
        color: panel.softText(0.045)
        border.color: Shell.trim(hub.dockerError).length > 0 ? Qt.rgba(0.94, 0.27, 0.27, 0.35) : panel.accentSoft(0.18)
        border.width: 1
        implicitHeight: glanceDk.implicitHeight + 24
        MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "containers" }
        Column {
          id: glanceDk
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14; spacing: 10
          RowLayout {
            width: parent.width; spacing: 10
            Image {
              source: "file:///usr/share/icons/hicolor/256x256/apps/docker.png"
              sourceSize.width: 28; sourceSize.height: 28
              width: 28; height: 28
              fillMode: Image.PreserveAspectFit
            }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Containers"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: panel.runningDockerCount() + " running of " + hub.dockerContainers.length; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Column {
            width: parent.width
            spacing: 6
            Text { visible: Shell.trim(hub.dockerError).length > 0; textFormat: Text.PlainText; text: hub.dockerError; color: "#ef4444"; font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
            Text { visible: Shell.trim(hub.dockerError).length === 0 && hub.dockerContainers.length === 0; textFormat: Text.PlainText; text: "No containers found."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
            Column {
              visible: Shell.trim(hub.dockerError).length === 0 && hub.dockerContainers.length > 0
              width: parent.width
              spacing: 4
              Repeater {
                model: Math.min(hub.dockerContainers.length, 5)
                delegate: RowLayout {
                  required property int index
                  width: parent ? parent.width : 0
                  spacing: 8
                  Rectangle {
                    width: 8; height: 8; radius: 4
                    color: panel.dockerStateTone(hub.dockerContainers[index].state)
                    Layout.alignment: Qt.AlignVCenter
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: hub.dockerContainers[index].name || "unknown"
                    color: Color.menu.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: hub.dockerContainers[index].state || ""
                    color: panel.dockerStateTone(hub.dockerContainers[index].state)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }
              }
              Text {
                visible: hub.dockerContainers.length > 5
                textFormat: Text.PlainText
                text: "+" + (hub.dockerContainers.length - 5) + " more"
                color: panel.softText(0.7)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          Text { textFormat: Text.PlainText; text: "Open Containers tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // Dev glance
      Rectangle {
        width: 320
        radius: 14
        color: panel.softText(0.045)
        border.color: hub.codeServerRunning ? panel.accentSoft(0.30) : panel.accentSoft(0.16)
        border.width: 1
        implicitHeight: glanceDev.implicitHeight + 24
        MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "dev" }
        Column {
          id: glanceDev
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14; spacing: 10
          RowLayout {
            width: parent.width; spacing: 10
            Text { textFormat: Text.PlainText; text: "󰅨"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Development"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text {
                textFormat: Text.PlainText
                text: Shell.trim(hub.preferredEditor).length > 0 ? ("Editor: " + DevTools.label(hub.preferredEditor)) : "No preferred editor set"
                color: panel.softText(0.78)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Column {
            width: parent.width
            spacing: 6
            Text { textFormat: Text.PlainText; text: "Repositories: " + (hub.devRepos ? hub.devRepos.length : 0); color: Color.menu.text; font.family: Style.font.family; font.bold: true }
            Text { textFormat: Text.PlainText; text: "VS Code Server: " + (hub.codeServerPresent ? hub.codeServerState : "not set up"); color: hub.codeServerRunning ? "#22c55e" : panel.softText(0.82); font.family: Style.font.family }
            Text { visible: Shell.trim(hub.devStatus).length > 0; textFormat: Text.PlainText; text: hub.devStatus; color: panel.softText(0.68); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
          }

          Text { textFormat: Text.PlainText; text: "Open Dev tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }

      // Games & storage glance
      Rectangle {
        width: 320
        radius: 14
        color: panel.softText(0.045)
        border.color: panel.accentSoft(0.18)
        border.width: 1
        implicitHeight: glanceGm.implicitHeight + 24
        MouseArea { anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor; onClicked: panel.currentTab = "games" }
        Column {
          id: glanceGm
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 14; spacing: 10
          RowLayout {
            width: parent.width; spacing: 10
            Text { textFormat: Text.PlainText; text: "󰊴"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Games & storage"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text { textFormat: Text.PlainText; text: hub.gameMount; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Rectangle {
              radius: 10
              color: hub.gameMountPresent ? panel.accentSoft(0.22) : panel.softText(0.1)
              implicitWidth: glanceMountBadge.implicitWidth + 14
              implicitHeight: glanceMountBadge.implicitHeight + 8
              Text { id: glanceMountBadge; anchors.centerIn: parent; textFormat: Text.PlainText; text: hub.gameMountPresent ? "mounted" : "not mounted"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Column {
            width: parent.width
            spacing: 8
            Text {
              visible: !hub.gameMountPresent
              textFormat: Text.PlainText
              text: "Game partition not mounted"
              color: panel.softText(0.8)
              font.family: Style.font.family
              wrapMode: Text.Wrap
              width: parent.width
            }
            Column {
              visible: hub.gameMountPresent
              width: parent.width
              spacing: 6
              Rectangle {
                width: parent.width
                height: 10
                radius: 5
                color: panel.softText(0.12)
                clip: true
                Rectangle {
                  height: parent.height
                  radius: 5
                  width: parent.width * hub.gameMountUseRatio
                  color: panel.storageUseColor(hub.gameMountUseRatio)
                  Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                }
              }
              RowLayout {
                width: parent.width
                spacing: 8
                Text { textFormat: Text.PlainText; text: (hub.gameMountUsePercentText.length > 0 ? hub.gameMountUsePercentText : Math.round(hub.gameMountUseRatio * 100) + "%") + " used"; color: panel.storageUseColor(hub.gameMountUseRatio); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
                Item { Layout.fillWidth: true }
                Text { textFormat: Text.PlainText; text: Shell.humanBytes(hub.gameMountUsedBytes) + " / " + Shell.humanBytes(hub.gameMountTotalBytes); color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
              }
              Text { textFormat: Text.PlainText; text: Shell.humanBytes(hub.gameMountAvailBytes) + " free"; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Column {
              width: parent.width
              spacing: 2
              Text { textFormat: Text.PlainText; text: "Steam: " + (hub.steamRunning ? "running" : "stopped") + " • games: " + (hub.steamGameCount >= 0 ? hub.steamGameCount : "?"); color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Text { textFormat: Text.PlainText; text: "Battle.net: " + (hub.bnetRunning ? "running" : "stopped") + " • games: " + (hub.bnetGameCount >= 0 ? hub.bnetGameCount : "?"); color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
          }

          Text { textFormat: Text.PlainText; text: "Open Gaming tab →"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption }
        }
      }
    }

  }

  Column {
    visible: panel.overviewSubTab === "update"
    width: parent.width
    spacing: Style.spacing.md

    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: omarchyUpdateCol.implicitHeight + 24
      Column {
        id: omarchyUpdateCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 12
        RowLayout {
          width: parent.width
          spacing: 10
          Text { textFormat: Text.PlainText; text: "󰚰"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { textFormat: Text.PlainText; text: "Update Omarchy"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { textFormat: Text.PlainText; text: "Run Omarchy update in your default terminal (so you can answer prompts) while streaming live output below. The hub will try to focus the terminal."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
          }
        }
        Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }
        Text {
          visible: Shell.trim(hub.omarchyUpdateStatus).length > 0
          textFormat: Text.PlainText
          text: hub.omarchyUpdateStatus
          color: hub.omarchyUpdateStatus.indexOf("exited") === 0 ? "#ef4444" : panel.softText(0.85)
          font.family: Style.font.family
          wrapMode: Text.Wrap
          width: parent.width
        }
        Flow {
          width: parent.width
          spacing: 8
          Button {
            iconText: "󰚰"
            text: hub.omarchyUpdateRunning ? "Updating…" : "Update Omarchy"
            active: true
            enabled: !hub.omarchyUpdateRunning
            tooltipText: "Run omarchy-update and show live log"
            onClicked: hub.runOmarchyUpdateInPanel()
          }
          Button {
            iconText: "󰓛"
            text: "Stop"
            enabled: hub.omarchyUpdateRunning
            tooltipText: "Stop live log/process"
            onClicked: hub.stopOmarchyUpdateLog()
          }
          Button {
            iconText: "󰆴"
            text: "Clear log"
            enabled: !hub.omarchyUpdateRunning && Shell.trim(hub.omarchyUpdateLog).length > 0
            onClicked: hub.clearOmarchyUpdateLog()
          }
        }
      }
    }

    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.04)
      border.color: panel.softText(0.10)
      border.width: 1
      implicitHeight: Math.max(220, omarchyLogCol.implicitHeight + 20)
      Column {
        id: omarchyLogCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 10
        spacing: 8
        Text { textFormat: Text.PlainText; text: "Live log"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
        Rectangle {
          width: parent.width
          height: 320
          radius: 8
          color: Qt.rgba(0, 0, 0, 0.18)
          border.color: panel.softText(0.08)
          border.width: 1
          clip: true
          Flickable {
            id: omarchyLogFlick
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: omarchyLogText.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Text {
              id: omarchyLogText
              width: omarchyLogFlick.width
              textFormat: Text.PlainText
              text: Shell.trim(hub.omarchyUpdateLog).length > 0 ? hub.omarchyUpdateLog : "No log output yet."
              color: Shell.trim(hub.omarchyUpdateLog).length > 0 ? panel.softText(0.92) : panel.softText(0.55)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WrapAnywhere
            }
            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
          }
        }
      }
    }
  }

}
