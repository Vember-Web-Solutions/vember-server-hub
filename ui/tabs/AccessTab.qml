// AccessTab: one tab of the Vember Server Hub panel.
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

  visible: panel.currentTab === "access"
  width: parent.width
  spacing: Style.spacing.md

  // Access sub-nav
  Row {
    spacing: 8
    Button {
      iconText: "󰖂"
      text: "Tailnet"
      active: panel.accessSubTab === "tailnet"
      onClicked: panel.accessSubTab = "tailnet"
    }
    Button {
      iconText: "󰣀"
      text: "SSH"
      active: panel.accessSubTab === "ssh"
      onClicked: panel.accessSubTab = "ssh"
    }
  }

  Rectangle {
    visible: panel.accessSubTab === "tailnet"
    width: parent.width
    radius: Style.cornerRadius
    color: panel.softText(0.04)
    border.color: panel.softText(0.08)
    border.width: 1
    implicitHeight: tsMain.implicitHeight + 24
    Column {
      id: tsMain
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 12; spacing: 10

      RowLayout {
        id: tsTwoCol
        width: parent.width
        spacing: 16

        // Left: Tailnet / this device / controls
        Column {
          id: tsLeft
          Layout.preferredWidth: Math.max(280, parent.width * 0.42)
          Layout.alignment: Qt.AlignTop
          spacing: 10

          RowLayout {
            width: parent.width; spacing: 10
            Text { textFormat: Text.PlainText; text: "󰖂"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 2
              Text { textFormat: Text.PlainText; text: "Tailnet"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
              Text {
                textFormat: Text.PlainText
                text: Shell.trim(hub.tailscaleTailnetName).length > 0 ? hub.tailscaleTailnetName : "unknown"
                color: panel.softText(0.85)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
            Rectangle {
              radius: 10
              color: hub.tailscaleActive === "active" ? panel.accentSoft(0.22) : panel.softText(0.1)
              implicitWidth: tsBadge.implicitWidth + 14
              implicitHeight: tsBadge.implicitHeight + 8
              Text { id: tsBadge; anchors.centerIn: parent; textFormat: Text.PlainText; text: hub.tailscaleActive; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
          }

          Text { textFormat: Text.PlainText; text: "Tailnet connection status, this device, peers, and service controls."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
          Text { textFormat: Text.PlainText; text: "tailscaled • enabled: " + hub.tailscaleEnabled; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { visible: Shell.trim(hub.tailscaleNote).length > 0; textFormat: Text.PlainText; text: hub.tailscaleNote; color: Color.menu.text; font.family: Style.font.family; wrapMode: Text.Wrap; width: parent.width }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Text { textFormat: Text.PlainText; text: "This device"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
          Column {
            visible: !!hub.tailscaleSelf
            width: parent.width
            spacing: 3
            RowLayout {
              width: parent.width; spacing: 8
              Rectangle { width: 10; height: 10; radius: 5; color: "#22c55e" }
              Text { textFormat: Text.PlainText; text: hub.tailscaleSelf ? (hub.tailscaleSelf.hostName || "vemberos") : "This device"; color: Color.menu.text; font.family: Style.font.family; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
              Text { visible: hub.tailscaleSelf && Shell.trim(hub.tailscaleSelf.os).length > 0; textFormat: Text.PlainText; text: hub.tailscaleSelf ? hub.tailscaleSelf.os : ""; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption }
            }
            Text { visible: hub.tailscaleSelf && Shell.trim(hub.tailscaleSelf.dnsName).length > 0; textFormat: Text.PlainText; text: hub.tailscaleSelf ? hub.tailscaleSelf.dnsName : ""; color: panel.softText(0.85); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
          }
          Text { visible: !hub.tailscaleSelf; textFormat: Text.PlainText; text: "No device status available."; color: panel.softText(0.7); font.family: Style.font.family; font.pixelSize: Style.font.caption }

          Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

          Text { textFormat: Text.PlainText; text: "Service controls"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
          Flow {
            width: parent.width
            spacing: 8
            Button { iconText: "󰐊"; text: "Start"; tooltipText: "pkexec systemctl start tailscaled"; enabled: !hub.tailscaleBusy; onClicked: hub.runTailscaleAction("start") }
            Button { iconText: "󰓛"; text: "Stop"; tooltipText: "pkexec systemctl stop tailscaled"; enabled: !hub.tailscaleBusy; onClicked: hub.runTailscaleAction("stop") }
            Button { iconText: "󰑐"; text: "Restart"; tooltipText: "pkexec systemctl restart tailscaled"; enabled: !hub.tailscaleBusy; onClicked: hub.runTailscaleAction("restart") }
            Button { iconText: "󰆍"; text: "Start (terminal)"; tooltipText: "sudo in terminal"; onClicked: hub.runTailscaleActionInTerminal("start") }
            Button { iconText: "󰆍"; text: "Restart (terminal)"; tooltipText: "sudo in terminal"; onClicked: hub.runTailscaleActionInTerminal("restart") }
          }
        }

        // Divider
        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          Layout.minimumHeight: 180
          color: panel.softText(0.08)
        }

        // Right: Members
        Column {
          id: tsRight
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignTop
          spacing: 8

          RowLayout {
            width: parent.width
            Text { textFormat: Text.PlainText; text: "Members"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
            Text { textFormat: Text.PlainText; text: "(" + hub.tailscalePeers.length + ")"; color: panel.softText(0.75); font.family: Style.font.family }
            Item { Layout.fillWidth: true }
          }

          Text {
            visible: hub.tailscalePeers.length === 0
            textFormat: Text.PlainText
            text: "No peer members found."
            color: panel.softText(0.7)
            font.family: Style.font.family
          }

          Column {
            width: parent.width
            spacing: 0
            Repeater {
              model: hub.tailscalePeers
              delegate: Column {
                required property var modelData
                required property int index
                width: tsRight.width
                spacing: 0

                Rectangle {
                  visible: index > 0
                  width: parent.width
                  height: 1
                  color: panel.softText(0.07)
                }

                RowLayout {
                  width: parent.width
                  height: implicitHeight
                  spacing: 10

                  Item {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 36
                    Rectangle {
                      anchors.centerIn: parent
                      width: 10; height: 10; radius: 5
                      color: modelData.online ? "#22c55e" : "#ef4444"
                    }
                  }

                  Column {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    spacing: 2
                    RowLayout {
                      width: parent.width; spacing: 8
                      Text {
                        textFormat: Text.PlainText
                        text: modelData.hostName || modelData.dnsName || "Unknown"
                        color: Color.menu.text; font.family: Style.font.family; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true
                      }
                      Text {
                        textFormat: Text.PlainText
                        text: modelData.online ? "online" : "offline"
                        color: modelData.online ? "#22c55e" : "#ef4444"
                        font.family: Style.font.family; font.pixelSize: Style.font.caption
                      }
                    }
                    Text {
                      visible: Shell.trim(modelData.dnsName).length > 0
                      textFormat: Text.PlainText
                      text: modelData.dnsName
                      color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width
                    }
                  }

                  Column {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                      visible: modelData.ips && modelData.ips.length > 0
                      textFormat: Text.PlainText
                      text: modelData.ips && modelData.ips.length > 0 ? modelData.ips[0] : ""
                      color: panel.softText(0.88); font.family: Style.font.family; font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                    }
                    Text {
                      visible: Shell.trim(modelData.os).length > 0
                      textFormat: Text.PlainText
                      text: modelData.os
                      color: panel.softText(0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // SSH
  Rectangle {
    visible: panel.accessSubTab === "ssh"
    width: parent.width
    radius: Style.cornerRadius
    color: panel.softText(0.04)
    border.color: panel.softText(0.08)
    border.width: 1
    implicitHeight: sshCol.implicitHeight + 24
    Column {
      id: sshCol
      property string authKeysView: "keys"
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 12; spacing: 10

      RowLayout {
        width: parent.width; spacing: 10
        Text { textFormat: Text.PlainText; text: "󰣀"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.icon }
        ColumnLayout {
          Layout.fillWidth: true; spacing: 2
          Text { textFormat: Text.PlainText; text: "SSH"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
          Text { textFormat: Text.PlainText; text: "SSH service status and authorized key management for remote access to this machine."; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
          Text { textFormat: Text.PlainText; text: "Host: " + (Shell.trim(hub.sshHostName).length > 0 ? hub.sshHostName : "vemberos"); color: panel.softText(0.82); font.family: Style.font.family; font.pixelSize: Style.font.body }
        }
        Rectangle {
          radius: 10
          color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.18) : panel.softText(0.1)
          border.color: hub.sshActive === "active" ? Qt.rgba(0.13, 0.77, 0.37, 0.35) : "transparent"
          border.width: hub.sshActive === "active" ? 1 : 0
          implicitWidth: sshBadge.implicitWidth + 14
          implicitHeight: sshBadge.implicitHeight + 8
          Text {
            id: sshBadge
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: hub.sshActive
            color: hub.sshActive === "active" ? "#22c55e" : Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: hub.sshActive === "active"
          }
        }
      }

      Text { textFormat: Text.PlainText; text: "sshd • enabled: " + hub.sshEnabled; color: panel.softText(0.78); font.family: Style.font.family; font.pixelSize: Style.font.caption }

      Rectangle { width: parent.width; height: 1; color: panel.softText(0.08) }

      Text { textFormat: Text.PlainText; text: "Authorized keys"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
      Text { textFormat: Text.PlainText; text: "Manage public keys allowed to sign in over SSH. Add a key, select one to review/remove, or open the file for manual edits."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
      Text {
        visible: Shell.trim(hub.sshAuthorizedKeysStatus).length > 0
        textFormat: Text.PlainText
        text: hub.sshAuthorizedKeysStatus
        color: panel.softText(0.85)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        width: parent.width
      }

      Column {
        visible: Shell.trim(hub.sshGeneratedPublicKey).length > 0
        width: parent.width
        spacing: 6
        Text { textFormat: Text.PlainText; text: "Generated public key"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Rectangle {
          width: parent.width
          radius: 8
          color: panel.softText(0.03)
          border.color: panel.accentSoft(0.2)
          border.width: 1
          implicitHeight: Math.max(56, genPubKeyText.implicitHeight + 12)
          TextEdit {
            id: genPubKeyText
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 8
            text: hub.sshGeneratedPublicKey
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: TextEdit.WrapAnywhere
            readOnly: true
            selectByMouse: true
            selectionColor: panel.accentSoft(0.35)
            selectedTextColor: Color.menu.text
          }
        }
      }

      // Nav bar
      Rectangle {
        width: parent.width
        radius: 10
        color: panel.softText(0.03)
        border.color: panel.softText(0.08)
        border.width: 1
        implicitHeight: authNavRow.implicitHeight + 10
        Row {
          id: authNavRow
          anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          anchors.margins: 6
          spacing: 6
          Button {
            iconText: "󰌋"
            text: "Keys"
            active: sshCol.authKeysView === "keys"
            onClicked: sshCol.authKeysView = "keys"
          }
          Button {
            iconText: "󰐕"
            text: "Add key"
            active: sshCol.authKeysView === "add"
            onClicked: sshCol.authKeysView = "add"
          }
          Button {
            iconText: "󰌆"
            text: hub.sshGenerateBusy ? "Generating…" : "Generate key"
            tooltipText: "Generate a new SSH identity keypair (~/.ssh/id_ed25519)"
            enabled: !hub.sshGenerateBusy
            onClicked: hub.generateSshIdentityKey()
          }
          Item { width: 8; height: 1 }
          Button {
            iconText: "󰏫"
            text: "Open editor"
            tooltipText: "Open ~/.ssh/authorized_keys in editor"
            onClicked: hub.openAuthorizedKeysEditor()
          }
        }
      }

      // Keys view (list + details)
      RowLayout {
        visible: sshCol.authKeysView === "keys"
        width: parent.width
        spacing: 12

        // Left: keys list
        Column {
          id: authKeysLeft
          Layout.preferredWidth: Math.max(260, parent.width * 0.42)
          Layout.alignment: Qt.AlignTop
          spacing: 6

          Text {
            visible: !hub.sshAuthorizedKeys || hub.sshAuthorizedKeys.length === 0
            textFormat: Text.PlainText
            text: "No authorized keys found."
            color: panel.softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }

          Repeater {
            model: hub.sshAuthorizedKeys || []
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: authKeysLeft.width
              radius: 8
              color: hub.sshSelectedKeyIndex === index ? panel.accentSoft(0.14) : panel.softText(0.03)
              border.color: hub.sshSelectedKeyIndex === index ? panel.accentSoft(0.35) : panel.softText(0.08)
              border.width: 1
              implicitHeight: keyItemCol.implicitHeight + 12
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: hub.sshSelectedKeyData = (hub.sshSelectedKeyData === modelData.keyData ? "" : modelData.keyData)
              }
              Column {
                id: keyItemCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 8
                spacing: 2
                Text {
                  textFormat: Text.PlainText
                  text: Shell.trim(modelData.comment || "").length > 0 ? modelData.comment : (modelData.type || "Key")
                  color: Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }
                Text {
                  textFormat: Text.PlainText
                  text: (modelData.type || "key") + " • " + (modelData.keyPreview || "")
                  color: panel.softText(0.72)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }
        }

        // Divider
        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          Layout.minimumHeight: 120
          color: panel.softText(0.08)
        }

        // Right: details
        Column {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignTop
          spacing: 10

          Text { textFormat: Text.PlainText; text: "Selected key"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
          Text {
            visible: hub.sshSelectedKeyIndex < 0 || hub.sshSelectedKeyIndex >= (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
            textFormat: Text.PlainText
            text: "Select a key to view details, remove it, or switch to Add key."
            color: panel.softText(0.7)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            width: parent.width
          }
          Column {
            visible: hub.sshSelectedKeyIndex >= 0 && hub.sshSelectedKeyIndex < (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
            width: parent.width
            spacing: 6
            Text {
              textFormat: Text.PlainText
              text: "Type: " + (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] ? (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].type || "unknown") : "")
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Text {
              textFormat: Text.PlainText
              text: "Comment: " + (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] && Shell.trim(hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].comment).length > 0 ? hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].comment : "(none)")
              color: Color.menu.text
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              width: parent.width
            }
            Rectangle {
              width: parent.width
              radius: 8
              color: panel.softText(0.03)
              border.color: panel.softText(0.08)
              border.width: 1
              implicitHeight: selKeyText.implicitHeight + 12
              Text {
                id: selKeyText
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 8
                textFormat: Text.PlainText
                text: hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex] ? (hub.sshAuthorizedKeys[hub.sshSelectedKeyIndex].line || "") : ""
                color: panel.softText(0.85)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
                width: parent.width
              }
            }
            Flow {
              width: parent.width
              spacing: 8
              Button {
                iconText: "󰆴"
                text: "Remove selected"
                tooltipText: "Remove the selected key from authorized_keys"
                enabled: hub.sshSelectedKeyIndex >= 0 && hub.sshSelectedKeyIndex < (hub.sshAuthorizedKeys ? hub.sshAuthorizedKeys.length : 0)
                onClicked: panel.confirmRemoveSshKey = true
              }
            }
          }
        }
      }

      // Add key view
      Column {
        visible: sshCol.authKeysView === "add"
        width: parent.width
        spacing: 10
        Text { textFormat: Text.PlainText; text: "Add authorized key"; color: Color.menu.text; font.family: Style.font.family; font.bold: true }
        Text { textFormat: Text.PlainText; text: "Paste a public key (single line) to append to ~/.ssh/authorized_keys. Use Open editor for bulk or advanced edits."; color: panel.softText(0.75); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; width: parent.width }
        Rectangle {
          width: parent.width
          radius: 8
          color: panel.softText(0.03)
          border.color: panel.softText(0.08)
          border.width: 1
          implicitHeight: 90
          TextInput {
            id: newKeyInput
            anchors.fill: parent
            anchors.margins: 8
            color: Color.menu.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: TextInput.WrapAnywhere
            selectByMouse: true
            clip: true
            text: hub.sshNewKeyText
            onTextChanged: hub.sshNewKeyText = text
          }
        }
        Flow {
          width: parent.width
          spacing: 8
          Button {
            iconText: "󰐕"
            text: "Add key"
            tooltipText: "Append this public key to authorized_keys"
            onClicked: hub.addAuthorizedKey()
          }
        }
      }
    }
  }
}
