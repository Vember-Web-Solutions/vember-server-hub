// Reordering the tab strip.
//
// Extracted verbatim from HubPanel.qml. `panel` is the HubPanel root, so
// `panel.hub` is the backend and `panel.<helper>()` is a shared formatting
// helper.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons

Rectangle {
  required property var panel
  required property real cardRadius

  visible: panel.arrangeTabsOpen
  anchors.fill: parent
  radius: cardRadius
  color: Qt.rgba(0, 0, 0, 0.45)
  z: 155

  MouseArea {
    anchors.fill: parent
    onClicked: panel.arrangeTabsOpen = false
  }

  Rectangle {
    id: arrangeTabsDialog
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 460)
    radius: 14
    color: Color.menu.background
    border.color: panel.accentSoft(0.25)
    border.width: 1
    implicitHeight: arrangeTabsCol.implicitHeight + 28

    MouseArea { anchors.fill: parent; onClicked: {} }

    Column {
      id: arrangeTabsCol
      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: 14
      spacing: 12

      RowLayout {
        width: parent.width
        spacing: 10
        Text { textFormat: Text.PlainText; text: "󰁁"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.iconLarge }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { textFormat: Text.PlainText; text: "Arrange tabs"; color: Color.menu.text; font.family: Style.font.family; font.pixelSize: Style.font.heading; font.bold: true }
          Text { textFormat: Text.PlainText; text: "Move tabs up or down, then save the order."; color: panel.softText(0.8); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
      }

      Column {
        width: parent.width
        spacing: 6
        Repeater {
          model: panel.arrangeTabOrderDraft || []
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: parent ? parent.width : 0
            radius: 8
            color: panel.softText(0.04)
            border.color: panel.softText(0.08)
            border.width: 1
            implicitHeight: arrangeRow.implicitHeight + 12
            RowLayout {
              id: arrangeRow
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
              anchors.margins: 8
              spacing: 8
              Text {
                textFormat: Text.PlainText
                text: panel.tabDef(modelData).icon
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                text: panel.tabDef(modelData).label
                color: Color.menu.text
                font.family: Style.font.family
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
              Button {
                iconText: "󰅃"
                tooltipText: "Move up"
                enabled: index > 0
                onClicked: panel.moveArrangeTabDraft(index, -1)
              }
              Button {
                iconText: "󰅀"
                tooltipText: "Move down"
                enabled: index < ((panel.arrangeTabOrderDraft || []).length - 1)
                onClicked: panel.moveArrangeTabDraft(index, 1)
              }
            }
          }
        }
      }

      Row {
        spacing: 8
        anchors.right: parent.right
        Button {
          text: "Cancel"
          onClicked: panel.arrangeTabsOpen = false
        }
        Button {
          iconText: "󰄬"
          text: "Save"
          active: true
          onClicked: panel.saveArrangeTabs()
        }
      }
    }
  }
}
