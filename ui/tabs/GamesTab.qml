// GamesTab: one tab of the Vember Server Hub panel.
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

Column {
  required property var panel

  visible: panel.currentTab === "games"
  width: parent.width
  spacing: Style.spacing.md

  // Gaming sub-nav
  Row {
    spacing: 8
    Button {
      iconText: "󰊴"
      text: "Launchers"
      active: panel.gamesSubTab === "launchers"
      onClicked: panel.gamesSubTab = "launchers"
    }
    Button {
      iconText: "󰀻"
      text: "Apps"
      active: panel.gamesSubTab === "apps"
      onClicked: panel.gamesSubTab = "apps"
    }
    Button {
      iconText: "󰒋"
      text: "Servers"
      active: panel.gamesSubTab === "servers"
      onClicked: panel.gamesSubTab = "servers"
    }
    Button {
      iconText: "󰋊"
      text: "Storage"
      active: panel.gamesSubTab === "storage"
      onClicked: panel.gamesSubTab = "storage"
    }
  }

  // Launchers tab
  Column {
    visible: panel.gamesSubTab === "launchers"
    width: parent.width
    spacing: Style.spacing.md

    // Launcher bar (installed launchers only)
    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: launcherBarCol.implicitHeight + 20
      Column {
        id: launcherBarCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 10
        spacing: 8
        Text { textFormat: Text.PlainText; text: "Launcher bar"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
        Text { textFormat: Text.PlainText; text: "Quick launch for installed game launchers."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
        Flow {
          width: parent.width
          spacing: 8
          Button {
            visible: hub.steamInstalled
            iconText: "󰓓"
            text: "Steam"
            tooltipText: "Launch Steam"
            onClicked: hub.launchSteam()
          }
          Button {
            visible: hub.bnetInstalled
            iconText: "󰖺"
            text: "Battle.net"
            tooltipText: "Launch Battle.net"
            onClicked: hub.launchBattleNet()
          }
          Repeater {
            model: {
              var out = [];
              var apps = hub.extraApps || [];
              for (var i = 0; i < apps.length; i++) {
                var a = apps[i];
                if (a && a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) out.push(a);
              }
              return out;
            }
            delegate: Button {
              required property var modelData
              iconText: modelData.id === "heroic" ? "󰊗" : (modelData.id === "lutris" ? "󰺷" : (modelData.id === "prismlauncher" ? "󰍳" : (modelData.id === "minecraft-launcher" ? "󰍳" : (modelData.id === "curseforge" ? "󰏗" : "󰐊"))))
              text: modelData.name || modelData.id
              tooltipText: "Launch " + (modelData.name || modelData.id)
              onClicked: hub.launchExtraApp(modelData.id)
            }
          }
          Text {
            visible: !hub.steamInstalled && !hub.bnetInstalled && (function() {
              var apps = hub.extraApps || [];
              for (var i = 0; i < apps.length; i++) { var a = apps[i]; if (a && a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) return false; }
              return true;
            })()
            textFormat: Text.PlainText
            text: "No installed launchers detected."
            color: panel.softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    Text { visible: hub.extraAppsScanBusy; textFormat: Text.PlainText; text: "Scanning launchers and apps…"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
    Text { visible: Shell.trim(hub.extraAppInstallStatus).length > 0; textFormat: Text.PlainText; text: hub.extraAppInstallStatus; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }

    // Live install log (shared runner)
    Rectangle {
      visible: !hub.installIsDev && (hub.installRunning || Shell.trim(hub.installLog).length > 0)
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.04)
      border.color: hub.installRunning ? panel.accentSoft(0.30) : panel.softText(0.10)
      border.width: 1
      implicitHeight: installLogColL.implicitHeight + 20
      Column {
        id: installLogColL
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
          height: 200
          radius: 8
          color: Qt.rgba(0, 0, 0, 0.18)
          border.color: panel.softText(0.08)
          border.width: 1
          clip: true
          Flickable {
            id: installLogFlickL
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: installLogTextL.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Text {
              id: installLogTextL
              width: installLogFlickL.width
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

    // Game library summary (total + per-launcher breakdown)
    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: libraryCol.implicitHeight + 24
      Column {
        id: libraryCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        property int steamCount: hub.steamGameCount >= 0 ? hub.steamGameCount : 0
        property int bnetCount: hub.bnetGameCount >= 0 ? hub.bnetGameCount : 0
        property int prismCount: hub.prismInstanceCount >= 0 ? hub.prismInstanceCount : 0
        property int totalKnownGames: steamCount + bnetCount + prismCount
        property bool hasKnownCounts: hub.steamGameCount >= 0 || hub.bnetGameCount >= 0 || hub.prismInstanceCount >= 0
        property var installedExtraLaunchers: {
          var out = [];
          var apps = hub.extraApps || [];
          for (var i = 0; i < apps.length; i++) {
            var a = apps[i];
            if (a && a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) out.push(a);
          }
          return out;
        }
        property bool hasAnyInstalled: hub.steamInstalled || hub.bnetInstalled || installedExtraLaunchers.length > 0

        Column {
          width: parent.width
          spacing: 2
          Text {
            textFormat: Text.PlainText
            text: libraryCol.hasKnownCounts ? String(libraryCol.totalKnownGames) : "—"
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Math.round(Style.font.heading * 2.2)
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText
            text: libraryCol.hasKnownCounts ? "games detected" : "game count unavailable"
            color: panel.softText(0.72)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Column {
          visible: libraryCol.hasAnyInstalled
          width: parent.width
          spacing: 10

          // Steam
          Column {
            visible: hub.steamInstalled
            width: parent.width
            spacing: 4
            RowLayout {
              width: parent.width
              spacing: 8
              Rectangle { width: 10; height: 10; radius: 2; color: "#66c0f4"; Layout.alignment: Qt.AlignVCenter }
              Text { textFormat: Text.PlainText; text: "Steam"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true }
              Text { textFormat: Text.PlainText; text: hub.steamGameCount >= 0 ? String(hub.steamGameCount) : "—"; color: "#66c0f4"; font.family: Style.font.family; font.bold: true }
            }
            Rectangle {
              width: parent.width
              height: 6
              radius: 3
              color: panel.softText(0.10)
              clip: true
              Rectangle {
                height: parent.height
                radius: 3
                width: libraryCol.totalKnownGames > 0 ? parent.width * (libraryCol.steamCount / libraryCol.totalKnownGames) : 0
                color: "#66c0f4"
                Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
              }
            }
            Text { visible: Shell.trim(hub.steamNote).length > 0; textFormat: Text.PlainText; text: hub.steamNote; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
          }

          // Battle.net
          Column {
            visible: hub.bnetInstalled
            width: parent.width
            spacing: 4
            RowLayout {
              width: parent.width
              spacing: 8
              Rectangle { width: 10; height: 10; radius: 2; color: "#00aeff"; Layout.alignment: Qt.AlignVCenter }
              Text { textFormat: Text.PlainText; text: "Battle.net"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true }
              Text { textFormat: Text.PlainText; text: hub.bnetGameCount >= 0 ? String(hub.bnetGameCount) : "—"; color: "#00aeff"; font.family: Style.font.family; font.bold: true }
            }
            Rectangle {
              width: parent.width
              height: 6
              radius: 3
              color: panel.softText(0.10)
              clip: true
              Rectangle {
                height: parent.height
                radius: 3
                width: libraryCol.totalKnownGames > 0 ? parent.width * (libraryCol.bnetCount / libraryCol.totalKnownGames) : 0
                color: "#00aeff"
                Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
              }
            }
          }

          // Prism modpack instances
          Column {
            visible: hub.prismInstanceCount >= 0
            width: parent.width
            spacing: 4
            RowLayout {
              width: parent.width
              spacing: 8
              Rectangle { width: 10; height: 10; radius: 2; color: "#7ac74f"; Layout.alignment: Qt.AlignVCenter }
              Text { textFormat: Text.PlainText; text: "Prism Launcher"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true }
              Text { textFormat: Text.PlainText; text: hub.prismInstanceCount >= 0 ? String(hub.prismInstanceCount) : "—"; color: "#7ac74f"; font.family: Style.font.family; font.bold: true }
            }
            Rectangle {
              width: parent.width
              height: 6
              radius: 3
              color: panel.softText(0.10)
              clip: true
              Rectangle {
                height: parent.height
                radius: 3
                width: libraryCol.totalKnownGames > 0 ? parent.width * (libraryCol.prismCount / libraryCol.totalKnownGames) : 0
                color: "#7ac74f"
                Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
              }
            }
            Text { textFormat: Text.PlainText; text: "modpack instances"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
          }

          Text {
            visible: libraryCol.installedExtraLaunchers.length > 0
            textFormat: Text.PlainText
            text: {
              var names = [];
              var list = libraryCol.installedExtraLaunchers || [];
              for (var i = 0; i < list.length; i++) { if (list[i] && list[i].name) names.push(list[i].name); }
              return "Also installed: " + names.join(", ");
            }
            color: panel.softText(0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
        }

        Text {
          visible: !libraryCol.hasAnyInstalled
          textFormat: Text.PlainText
          text: "No game launchers detected. Add one below to get started."
          color: panel.softText(0.75)
          font.family: Style.font.family
          wrapMode: Text.Wrap
          width: parent.width
        }
      }
    }

    // Available to add (not installed)
    Column {
      width: parent.width
      spacing: 8
      property var offerItems: {
        var out = [];
        if (!hub.steamInstalled) out.push({ kind: "steam", id: "steam", name: "Steam", description: "Valve game platform and library.", icon: "󰓓" });
        if (!hub.bnetInstalled) out.push({ kind: "bnet", id: "battlenet", name: "Battle.net", description: "Blizzard launcher (best-effort detection/prefix).", icon: "󰖺" });
        var apps = hub.extraApps || [];
        for (var i = 0; i < apps.length; i++) {
          var a = apps[i];
          if (a && !a.installed && (a.category === "launchers" || a.category === "minecraft" || a.category === "mods")) out.push({ kind: "extra", id: a.id, name: a.name, description: a.description || "", icon: a.id === "heroic" ? "󰊗" : (a.id === "lutris" ? "󰺷" : (a.id === "prismlauncher" ? "󰍳" : (a.id === "minecraft-launcher" ? "󰍳" : (a.id === "curseforge" ? "󰏗" : "󰊴")))) });
        }
        return out;
      }
      visible: offerItems.length > 0

      Text { textFormat: Text.PlainText; text: "Available to add"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
      Text { textFormat: Text.PlainText; text: "Install launchers to track and launch games from this hub."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }

      Flow {
        width: parent.width
        spacing: 14
        Repeater {
          model: parent.parent.offerItems
          delegate: Rectangle {
            required property var modelData
            width: 320
            radius: 14
            color: panel.softText(0.045)
            border.color: panel.softText(0.10)
            border.width: 1
            implicitHeight: offerCol.implicitHeight + 20
            Column {
              id: offerCol
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 12
              spacing: 8
              RowLayout {
                width: parent.width
                spacing: 10
                Text { textFormat: Text.PlainText; text: modelData.icon || "󰊴"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 28 }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text { textFormat: Text.PlainText; text: modelData.name || modelData.id; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                  Text { textFormat: Text.PlainText; text: "Not installed"; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
              }
              Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }
              Text { textFormat: Text.PlainText; text: modelData.description || ""; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
              Flow {
                width: parent.width
                spacing: 8
                Button {
                  iconText: modelData.id === "minecraft-launcher" ? "󰐕" : "󰏔"
                  text: (hub.installRunning && hub.installRunningId === modelData.id) ? "Installing…" : (modelData.kind === "bnet" ? "Set up" : (modelData.id === "minecraft-launcher" ? "Add" : "Install"))
                  tooltipText: modelData.kind === "steam" ? "Install Steam in the default terminal (answer the sudo prompt there)" : (modelData.kind === "bnet" ? "Open the Lutris Battle.net install page" : (modelData.id === "minecraft-launcher" ? "Add/install Minecraft Launcher" : ("Open terminal to install " + modelData.name)))
                  enabled: !hub.installRunning && !hub.omarchyUpdateRunning
                  onClicked: {
                    if (modelData.kind === "extra") hub.installExtraApp(modelData.id);
                    else if (modelData.kind === "steam") hub.installSteam();
                    else if (modelData.kind === "bnet") hub.openBattlenetSetup();
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Apps tab
  Column {
    visible: panel.gamesSubTab === "apps"
    width: parent.width
    spacing: Style.spacing.md

    Text { visible: hub.extraAppsScanBusy; textFormat: Text.PlainText; text: "Scanning launchers and apps…"; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }
    Text { visible: Shell.trim(hub.extraAppInstallStatus).length > 0; textFormat: Text.PlainText; text: hub.extraAppInstallStatus; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }

    // Live install log (shared runner)
    Rectangle {
      visible: !hub.installIsDev && (hub.installRunning || Shell.trim(hub.installLog).length > 0)
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.04)
      border.color: hub.installRunning ? panel.accentSoft(0.30) : panel.softText(0.10)
      border.width: 1
      implicitHeight: installLogColA.implicitHeight + 20
      Column {
        id: installLogColA
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
          height: 200
          radius: 8
          color: Qt.rgba(0, 0, 0, 0.18)
          border.color: panel.softText(0.08)
          border.width: 1
          clip: true
          Flickable {
            id: installLogFlickA
            anchors.fill: parent
            anchors.margins: 8
            contentWidth: width
            contentHeight: installLogTextA.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Text {
              id: installLogTextA
              width: installLogFlickA.width
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

    // Installed apps
    Column {
      width: parent.width
      spacing: 8
      property var installedApps: {
        var out = [];
        var apps = hub.extraApps || [];
        for (var i = 0; i < apps.length; i++) {
          var a = apps[i];
          if (a && a.category === "apps" && a.installed) out.push(a);
        }
        return out;
      }
      visible: installedApps.length > 0

      Text { textFormat: Text.PlainText; text: "Installed apps"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
      Flow {
        width: parent.width
        spacing: 14
        Repeater {
          model: parent.parent.installedApps
          delegate: Rectangle {
            required property var modelData
            width: 320
            radius: 14
            color: panel.softText(0.045)
            border.color: modelData.running ? panel.accentSoft(0.35) : panel.softText(0.10)
            border.width: 1
            implicitHeight: appInstalledCol.implicitHeight + 20
            Column {
              id: appInstalledCol
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 12
              spacing: 8
              RowLayout {
                width: parent.width
                spacing: 10
                Text { textFormat: Text.PlainText; text: modelData.id === "discord" ? "󰙯" : "󰀻"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 28 }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text { textFormat: Text.PlainText; text: modelData.name || modelData.id; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                  Text { textFormat: Text.PlainText; text: modelData.running ? "Installed • running" : "Installed"; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
              }
              Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }
              Text { visible: Shell.trim(modelData.description || "").length > 0; textFormat: Text.PlainText; text: modelData.description || ""; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
              Flow {
                width: parent.width
                spacing: 8
                Button {
                  iconText: "󰐊"
                  text: "Launch"
                  onClicked: hub.launchExtraApp(modelData.id)
                }
              }
            }
          }
        }
      }
    }

    // Offers (not installed)
    Column {
      width: parent.width
      spacing: 8
      property var offerApps: {
        var out = [];
        var apps = hub.extraApps || [];
        for (var i = 0; i < apps.length; i++) {
          var a = apps[i];
          if (a && a.category === "apps" && !a.installed) out.push(a);
        }
        return out;
      }
      visible: offerApps.length > 0

      Text { textFormat: Text.PlainText; text: "Available to add"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
      Flow {
        width: parent.width
        spacing: 14
        Repeater {
          model: parent.parent.offerApps
          delegate: Rectangle {
            required property var modelData
            width: 320
            radius: 14
            color: panel.softText(0.045)
            border.color: panel.softText(0.10)
            border.width: 1
            implicitHeight: appOfferCol.implicitHeight + 20
            Column {
              id: appOfferCol
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 12
              spacing: 8
              RowLayout {
                width: parent.width
                spacing: 10
                Text { textFormat: Text.PlainText; text: modelData.id === "discord" ? "󰙯" : "󰀻"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 28 }
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text { textFormat: Text.PlainText; text: modelData.name || modelData.id; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
                  Text { textFormat: Text.PlainText; text: "Not installed"; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
                }
              }
              Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }
              Text { visible: Shell.trim(modelData.description || "").length > 0; textFormat: Text.PlainText; text: modelData.description || ""; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
              Flow {
                width: parent.width
                spacing: 8
                Button {
                  iconText: "󰏔"
                  text: (hub.installRunning && hub.installRunningId === modelData.id) ? "Installing…" : "Install"
                  tooltipText: "Install " + (modelData.name || modelData.id) + " in the default terminal"
                  enabled: !hub.installRunning && !hub.omarchyUpdateRunning
                  onClicked: hub.installExtraApp(modelData.id)
                }
              }
            }
          }
        }
      }
    }

    Text {
      visible: (function() {
        var apps = hub.extraApps || [];
        var hasAny = false;
        for (var i = 0; i < apps.length; i++) { if (apps[i] && apps[i].category === "apps") { hasAny = true; break; } }
        return !hasAny;
      })() && !hub.extraAppsScanBusy
      textFormat: Text.PlainText
      text: "No app offers configured."
      color: panel.softText(0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  // Servers tab
  Column {
    visible: panel.gamesSubTab === "servers"
    width: parent.width
    spacing: Style.spacing.md

    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: gameServersCol.implicitHeight + 24
      Column {
        id: gameServersCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 10
        RowLayout {
          width: parent.width; spacing: 10
          Text { textFormat: Text.PlainText; text: "󰒋"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
          ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { textFormat: Text.PlainText; text: "Game servers"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { textFormat: Text.PlainText; text: "Detected game server containers (Docker) and Steam dedicated servers installed on this host (best-effort). Container controls are available for Docker servers."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
          }
        }

        Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

        property var detectedGameServers: {
          var out = [];
          var list = hub.dockerContainers || [];
          var keys = ["minecraft", "valheim", "factorio", "palworld", "terraria", "ark", "cs2", "csgo", "rust", "satisfactory", "7dtd", "zomboid", "projectzomboid", "enshrouded", "foundry", "vintage", "vrising", "conan", "dayz", "game", "gameserver", "pterodactyl", "crafty", "steamcmd"];
          for (var i = 0; i < list.length; i++) {
            var c = list[i] || {};
            var hay = ((c.name || "") + " " + (c.image || "")).toLowerCase();
            var match = false;
            for (var k = 0; k < keys.length; k++) { if (hay.indexOf(keys[k]) !== -1) { match = true; break; } }
            if (match) out.push({ serverType: "container", name: c.name || "unknown", image: c.image || "", state: c.state || "", status: c.status || "" });
          }
          var steamServers = hub.steamDedicatedServers || [];
          for (var s = 0; s < steamServers.length; s++) {
            var ss = steamServers[s] || {};
            out.push({ serverType: "steam", name: ss.name || "Steam Dedicated Server", image: ss.appid ? ("AppID " + ss.appid) : "Steam dedicated server", state: "installed", status: ss.installdir ? ("Install dir: " + ss.installdir) : "Host install (Steam)", installdir: ss.installdir || "", appid: ss.appid || "" });
          }
          return out;
        }

        Text {
          visible: (gameServersCol.detectedGameServers || []).length === 0
          textFormat: Text.PlainText
          text: Shell.trim(hub.dockerError).length > 0 ? hub.dockerError : "No game servers detected. Docker game server containers and installed Steam dedicated servers will appear here."
          color: Shell.trim(hub.dockerError).length > 0 ? "#ef4444" : panel.softText(0.75)
          font.family: Style.font.family
          wrapMode: Text.Wrap
          width: parent.width
        }

        Repeater {
          model: gameServersCol.detectedGameServers || []
          delegate: Rectangle {
            required property var modelData
            width: gameServersCol.width - 0
            radius: 8
            color: panel.softText(0.03)
            border.color: panel.softText(0.08)
            border.width: 1
            implicitHeight: gsRow.implicitHeight + 16
            Column {
              id: gsRow
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 8
              spacing: 6
              RowLayout {
                width: parent.width
                spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: modelData.serverType === "steam" ? "#66c0f4" : panel.dockerStateTone(modelData.state); Layout.alignment: Qt.AlignVCenter }
                ColumnLayout {
                  Layout.fillWidth: true; spacing: 2
                  Text { textFormat: Text.PlainText; text: modelData.name || "unknown"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                  Text { visible: Shell.trim(modelData.image || "").length > 0; textFormat: Text.PlainText; text: modelData.image; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                Text { textFormat: Text.PlainText; text: modelData.serverType === "steam" ? "Steam" : (modelData.state || ""); color: modelData.serverType === "steam" ? "#66c0f4" : panel.dockerStateTone(modelData.state); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              }
              Text { visible: Shell.trim(modelData.status || "").length > 0; textFormat: Text.PlainText; text: modelData.status; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
              Flow {
                visible: modelData.serverType !== "steam"
                width: parent.width
                spacing: 8
                Button {
                  iconText: "󰐊"
                  text: "Start"
                  enabled: !hub.dockerBusy
                  onClicked: hub.runDockerAction("start", modelData.name)
                }
                Button {
                  iconText: "󰓛"
                  text: "Stop"
                  enabled: !hub.dockerBusy
                  onClicked: hub.runDockerAction("stop", modelData.name)
                }
                Button {
                  iconText: "󰑐"
                  text: "Restart"
                  enabled: !hub.dockerBusy
                  onClicked: hub.runDockerAction("restart", modelData.name)
                }
              }
              Text {
                visible: modelData.serverType === "steam"
                textFormat: Text.PlainText
                text: "Host-installed Steam dedicated server (not a Docker container)."
                color: panel.softText(0.65)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                width: parent.width
              }
            }
          }
        }
      }
    }
  }

  // Storage tab
  Column {
    visible: panel.gamesSubTab === "storage"
    width: parent.width
    spacing: Style.spacing.md

    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: storageInfoCol.implicitHeight + 24
      Column {
        id: storageInfoCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 12
        RowLayout {
          width: parent.width; spacing: 10
          Text { textFormat: Text.PlainText; text: "󰋊"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
          ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { textFormat: Text.PlainText; text: "Game partition • " + hub.gameMount; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
            Column {
              visible: hub.gameMountPresent
              Layout.fillWidth: true
              spacing: 6
              Rectangle {
                width: parent.width
                height: 12
                radius: 6
                color: panel.softText(0.12)
                clip: true
                Rectangle {
                  height: parent.height
                  radius: 6
                  width: parent.width * hub.gameMountUseRatio
                  color: panel.storageUseColor(hub.gameMountUseRatio)
                  Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                }
              }
              RowLayout {
                width: parent.width
                spacing: 8
                Text {
                  textFormat: Text.PlainText
                  text: (hub.gameMountUsePercentText.length > 0 ? hub.gameMountUsePercentText : Math.round(hub.gameMountUseRatio * 100) + "%") + " used"
                  color: panel.storageUseColor(hub.gameMountUseRatio)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                  textFormat: Text.PlainText
                  text: Shell.humanBytes(hub.gameMountUsedBytes) + " used • " + Shell.humanBytes(hub.gameMountAvailBytes) + " free • " + Shell.humanBytes(hub.gameMountTotalBytes) + " total"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
            Text {
              visible: !hub.gameMountPresent
              textFormat: Text.PlainText
              text: "Not mounted / not found"
              color: panel.softText(0.85); font.family: Style.font.family; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
            Text { visible: Shell.trim(hub.gameMountError).length > 0; textFormat: Text.PlainText; text: hub.gameMountError; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
          }
          Rectangle {
            radius: 10
            color: hub.gameMountPresent ? panel.accentSoft(0.22) : panel.softText(0.1)
            implicitWidth: mountBadge3.implicitWidth + 14
            implicitHeight: mountBadge3.implicitHeight + 8
            Text { id: mountBadge3; anchors.centerIn: parent; textFormat: Text.PlainText; text: hub.gameMountPresent ? "mounted" : "not mounted"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          }
        }
      }
    }
  }
}
