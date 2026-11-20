// ContainersTab: one tab of the Vember Server Hub panel.
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

  id: containersTab
  visible: panel.currentTab === "containers"
  width: parent.width
  spacing: Style.spacing.md
  // Selection is keyed by container *name*, not list index: the 15s poll
  // reassigns hub.dockerContainers and can reorder it (a container created at
  // the top shifts every index down), which would silently point an index-based
  // selection at a different container — and its Remove button.
  property string selectedContainerName: ""

  Row {
    spacing: 8
    Button {
      iconText: "󰡨"
      text: "Containers"
      active: panel.containersSubTab === "containers"
      onClicked: panel.containersSubTab = "containers"
    }
    Button {
      iconText: "󰃢"
      text: "Prune"
      active: panel.containersSubTab === "prune"
      onClicked: panel.containersSubTab = "prune"
    }
    Button {
      iconText: "󰡨"
      text: "Docker Hub"
      active: panel.containersSubTab === "hub"
      onClicked: panel.containersSubTab = "hub"
    }
  }

  Column {
    visible: panel.containersSubTab === "containers"
    width: parent.width
    spacing: Style.spacing.md

    Text {
      textFormat: Text.PlainText
      text: "View and manage Docker containers. Select a container to see details and actions."
      color: panel.softText(0.8)
      font.family: Style.font.family
      wrapMode: Text.Wrap
      width: parent.width
    }

    RowLayout {
      width: parent.width
      spacing: 12

      // Left: container list
      Column {
        id: containersLeft
        Layout.preferredWidth: Math.max(280, parent.width * 0.42)
        Layout.alignment: Qt.AlignTop
        spacing: 6

        Text {
          visible: hub.dockerContainers.length === 0
          textFormat: Text.PlainText
          text: "No containers found."
          color: panel.softText(0.7)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: hub.dockerContainers
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: containersLeft.width
            radius: 8
            color: containersTab.selectedContainerName === modelData.name ? panel.accentSoft(0.14) : panel.softText(0.03)
            border.color: containersTab.selectedContainerName === modelData.name ? panel.accentSoft(0.35) : panel.softText(0.08)
            border.width: 1
            implicitHeight: ctrItemCol.implicitHeight + 12
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: containersTab.selectedContainerName = modelData.name
            }
            RowLayout {
              id: ctrItemCol
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 8
              spacing: 8
              Rectangle {
                width: 10; height: 10; radius: 5
                color: panel.dockerStateTone(modelData.state)
                Layout.alignment: Qt.AlignVCenter
              }
              Column {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  textFormat: Text.PlainText
                  text: modelData.name || "unknown"
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  visible: Shell.trim(modelData.image).length > 0
                  textFormat: Text.PlainText
                  text: modelData.image
                  color: panel.softText(0.7)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
              Text {
                textFormat: Text.PlainText
                text: modelData.state || ""
                color: panel.dockerStateTone(modelData.state)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }
              Button {
                // Present only when Docker publishes a browser-reachable port.
                // One click opens it and hands the desktop to the browser.
                visible: Shell.trim(modelData.webUrl || "").length > 0
                iconText: "󰕮"
                text: "Open"
                tooltipText: modelData.webUrl ? ("Open " + modelData.webUrl + " in your browser") : ""
                Layout.alignment: Qt.AlignVCenter
                onClicked: panel.hub.openContainerWebUrl(modelData.webUrl, modelData.name)
              }
            }
          }
        }
      }

      // Divider
      Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.minimumHeight: 160
        color: panel.softText(0.08)
      }

      // Right: details
      Column {
        id: containerDetails
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 10

        property var selected: (function() {
          var want = containersTab.selectedContainerName;
          if (!want) return null;
          var list = hub.dockerContainers || [];
          for (var i = 0; i < list.length; i++)
            if (list[i].name === want) return list[i];
          return null;
        })()
        // Key the size query off the container *name*, not the object. The 15s
        // poll reassigns hub.dockerContainers to fresh objects, so `selected`
        // changes identity every tick; onSelectedChanged would then re-run the
        // size query and blank the size to "Querying…" every 15 seconds.
        property string selectedName: selected ? (selected.name || "") : ""
        property bool selBusy: selected ? (hub.dockerBusy && hub.dockerBusyName === selected.name) : false
        property bool selPulling: selected ? (hub.dockerPullActive && hub.dockerPullingName === selected.name) : false
        property bool selPullResult: selected ? (!hub.dockerPullActive && hub.dockerPullingName === selected.name && Shell.trim(hub.dockerPullStatus).length > 0) : false

        onSelectedNameChanged: {
          if (hub && hub.refreshDockerDetailSize)
            hub.refreshDockerDetailSize(selectedName);
        }

        Text {
          visible: !containerDetails.selected
          textFormat: Text.PlainText
          text: "Select a container to view details and actions."
          color: panel.softText(0.7)
          font.family: Style.font.family
          wrapMode: Text.Wrap
          width: parent.width
        }

        Column {
          visible: !!containerDetails.selected
          width: parent.width
          spacing: 10

          RowLayout {
            width: parent.width
            spacing: 10
            Rectangle {
              width: 12; height: 12; radius: 6
              color: panel.dockerStateTone(containerDetails.selected ? containerDetails.selected.state : "")
              Layout.alignment: Qt.AlignVCenter
            }
            Text {
              textFormat: Text.PlainText
              text: containerDetails.selected ? (containerDetails.selected.name || "unknown") : ""
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
              Layout.fillWidth: true
              elide: Text.ElideRight
            }
            Text {
              textFormat: Text.PlainText
              text: containerDetails.selected ? (containerDetails.selected.state || "") : ""
              color: panel.dockerStateTone(containerDetails.selected ? containerDetails.selected.state : "")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Text {
            visible: Shell.trim(containerDetails.selected ? (containerDetails.selected.image || "") : "").length > 0
            textFormat: Text.PlainText
            text: "Image: " + (containerDetails.selected ? (containerDetails.selected.image || "") : "")
            color: panel.softText(0.85)
            font.family: Style.font.family
            wrapMode: Text.WrapAnywhere
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: "Status: " + (containerDetails.selected ? (containerDetails.selected.status || containerDetails.selected.state || "unknown") : "")
            color: Color.menu.text
            font.family: Style.font.family
            wrapMode: Text.Wrap
            width: parent.width
          }

          RowLayout {
            width: parent.width
            spacing: 8
            Text {
              textFormat: Text.PlainText
              text: "Size:"
              color: Color.menu.text
              font.family: Style.font.family
            }
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: {
                if (!containerDetails.selected) return "";
                if (hub.dockerDetailSizeBusy && hub.dockerDetailSizeName === containerDetails.selected.name) return "Querying…";
                if (hub.dockerDetailSizeName === containerDetails.selected.name && Shell.trim(hub.dockerDetailSizeError).length > 0) return hub.dockerDetailSizeError;
                if (hub.dockerDetailSizeName === containerDetails.selected.name && Shell.trim(hub.dockerDetailSizeText).length > 0) return hub.dockerDetailSizeText;
                return "—";
              }
              color: (hub.dockerDetailSizeName === (containerDetails.selected ? containerDetails.selected.name : "") && Shell.trim(hub.dockerDetailSizeError).length > 0) ? "#ef4444" : panel.softText(0.9)
              font.family: Style.font.family
              wrapMode: Text.Wrap
            }
            Button {
              visible: !!containerDetails.selected
              iconText: "󰑐"
              text: "Query"
              enabled: !!containerDetails.selected && !(hub.dockerDetailSizeBusy && hub.dockerDetailSizeName === containerDetails.selected.name)
              tooltipText: "Query container disk size (docker ps -s)"
              onClicked: if (containerDetails.selected) hub.refreshDockerDetailSize(containerDetails.selected.name)
            }
          }
          Text {
            visible: !!containerDetails.selected && hub.dockerDetailSizeName === containerDetails.selected.name && Shell.trim(hub.dockerDetailSizeText).length > 0
            textFormat: Text.PlainText
            text: "Writable layer / virtual size (as reported by Docker)."
            color: panel.softText(0.65)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }

          // Pull progress/result
          Column {
            visible: containerDetails.selPulling || containerDetails.selPullResult
            width: parent.width
            spacing: 6
            Rectangle {
              width: parent.width
              radius: 8
              color: panel.accentSoft(0.10)
              border.color: panel.accentSoft(0.20)
              border.width: 1
              implicitHeight: pullInfoCol.implicitHeight + 12
              Column {
                id: pullInfoCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 8
                spacing: 6
                Text {
                  textFormat: Text.PlainText
                  text: containerDetails.selPulling ? hub.dockerPullStatus : (hub.dockerPullResult.length > 0 ? hub.dockerPullResult : hub.dockerPullStatus)
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                  width: parent.width
                }
                Rectangle {
                  visible: containerDetails.selPulling
                  width: parent.width
                  height: 8
                  radius: 4
                  color: panel.softText(0.12)
                  clip: true
                  Rectangle {
                    id: selProgressFill
                    height: parent.height
                    radius: 4
                    color: Color.accent
                    width: hub.dockerPullPercent >= 0 ? (parent.width * hub.dockerPullPercent) : (parent.width * 0.35)
                    x: hub.dockerPullPercent >= 0 ? 0 : -width
                    Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                    SequentialAnimation on x {
                      running: hub.dockerPullPercent < 0 && containerDetails.selPulling
                      loops: Animation.Infinite
                      NumberAnimation { from: -selProgressFill.width; to: selProgressTrackW.width; duration: Style.duration(1200); easing.type: Easing.InOutQuad }
                    }
                  }
                  Item { id: selProgressTrackW; anchors.fill: parent }
                }
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Flow {
            width: parent.width
            spacing: 8
            Button {
              visible: !!containerDetails.selected && Shell.trim(containerDetails.selected.webUrl || "").length > 0
              iconText: "󰕮"
              text: "Open web UI"
              tooltipText: containerDetails.selected ? ("Open " + (containerDetails.selected.webUrl || "")) : ""
              enabled: !!containerDetails.selected
              onClicked: if (containerDetails.selected) panel.hub.openContainerWebUrl(containerDetails.selected.webUrl, containerDetails.selected.name)
            }
            Button {
              iconText: "󰐊"
              text: "Start"
              enabled: !containerDetails.selBusy && !!containerDetails.selected
              onClicked: if (containerDetails.selected) hub.runDockerAction("start", containerDetails.selected.name)
            }
            Button {
              iconText: "󰓛"
              text: "Stop"
              enabled: !containerDetails.selBusy && !!containerDetails.selected
              onClicked: if (containerDetails.selected) hub.runDockerAction("stop", containerDetails.selected.name)
            }
            Button {
              iconText: "󰑐"
              text: "Restart"
              enabled: !containerDetails.selBusy && !!containerDetails.selected
              onClicked: if (containerDetails.selected) hub.runDockerAction("restart", containerDetails.selected.name)
            }
            Button {
              iconText: "󰚰"
              text: containerDetails.selPulling ? "Pulling…" : "Pull image"
              enabled: !containerDetails.selBusy && !!containerDetails.selected && Shell.trim(containerDetails.selected.image || "").length > 0
              tooltipText: containerDetails.selected ? ("Pull / update image: " + (containerDetails.selected.image || "")) : ""
              onClicked: if (containerDetails.selected) hub.runDockerPull(containerDetails.selected.image, containerDetails.selected.name)
            }
            Button {
              // A stalled pull has no timeout and disables every action on the
              // container. Docker keeps the layers it already fetched, so
              // stopping and pulling again resumes rather than restarts.
              visible: containerDetails.selPulling
              iconText: "󰅖"
              text: "Stop pull"
              tooltipText: "Stop waiting for this image pull; the layers already downloaded are kept"
              onClicked: hub.cancelDockerPull()
            }
          }
        }
      }
    }
  }

  Column {
    visible: panel.containersSubTab === "prune"
    width: parent.width
    spacing: Style.spacing.md

    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: pruneCol.implicitHeight + 24
      Column {
        id: pruneCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 12
        RowLayout {
          width: parent.width
          spacing: 10
          Text { textFormat: Text.PlainText; text: "󰃢"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { textFormat: Text.PlainText; text: "Prune stopped containers"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { textFormat: Text.PlainText; text: "Remove all stopped containers to free disk space (docker container prune -f). Running containers are not affected."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
          }
        }
        Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }
        Text {
          textFormat: Text.PlainText
          text: "Containers: " + panel.runningDockerCount() + " running / " + (hub.dockerContainers ? hub.dockerContainers.length : 0) + " total"
          color: panel.softText(0.85)
          font.family: Style.font.family
          wrapMode: Text.Wrap
          width: parent.width
        }
        Text {
          visible: Shell.trim(hub.dockerError).length > 0
          textFormat: Text.PlainText
          text: hub.dockerError
          color: "#ef4444"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.Wrap
          width: parent.width
        }
        Text {
          visible: hub.dockerPruneBusy || Shell.trim(hub.lastActionMessage).indexOf("Prun") === 0 || Shell.trim(hub.lastActionMessage).indexOf("Docker container prune") === 0
          textFormat: Text.PlainText
          text: hub.dockerPruneBusy ? "Pruning stopped containers…" : hub.lastActionMessage
          color: (!hub.dockerPruneBusy && hub.lastActionMessage.indexOf("failed") !== -1) ? "#ef4444" : panel.softText(0.85)
          font.family: Style.font.family
          wrapMode: Text.Wrap
          width: parent.width
        }
        Flow {
          width: parent.width
          spacing: 8
          Button {
            iconText: "󰃢"
            text: hub.dockerPruneBusy ? "Pruning…" : "Prune stopped containers"
            active: true
            tooltipText: "Remove all stopped containers (docker container prune -f)"
            enabled: !hub.dockerPruneBusy && !hub.dockerBusy
            onClicked: panel.confirmPrune = true
          }
        }
      }
    }
  }

  Column {
    visible: panel.containersSubTab === "hub"
    width: parent.width
    spacing: Style.spacing.md

    Rectangle {
      width: parent.width
      radius: Style.cornerRadius
      color: panel.softText(0.05)
      border.color: panel.accentSoft(0.18)
      border.width: 1
      implicitHeight: dockerHubCol.implicitHeight + 24
      Column {
        id: dockerHubCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 14
        spacing: 12
        RowLayout {
          width: parent.width
          spacing: 10
          Text { textFormat: Text.PlainText; text: "󰡨"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { textFormat: Text.PlainText; text: "Docker Hub"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { textFormat: Text.PlainText; text: "Browse images, tags, and documentation on Docker Hub."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
          }
        }
        Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }
        Text { textFormat: Text.PlainText; text: "Find official images and community containers, then pull them from the Containers tab."; color: panel.softText(0.85); font.family: Style.font.family; wrapMode: Text.Wrap; width: parent.width }
        Flow {
          width: parent.width
          spacing: 8
          Button {
            iconText: "󰖟"
            text: "Open Docker Hub"
            active: true
            tooltipText: "Open https://hub.docker.com in your browser"
            onClicked: panel.hub.openExternalUrl("https://hub.docker.com", "Docker Hub")
          }
          Button {
            iconText: "󰍉"
            text: "Explore images"
            tooltipText: "Browse Docker Hub explore page"
            onClicked: panel.hub.openExternalUrl("https://hub.docker.com/search?q=&type=image", "the Docker Hub image search")
          }
        }
      }
    }
  }
}
