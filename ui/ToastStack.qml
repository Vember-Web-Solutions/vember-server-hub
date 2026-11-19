// Transient toast notifications.
//
// Extracted verbatim from HubPanel.qml. `panel` is the HubPanel root, so
// `panel.hub` is the backend and `panel.<helper>()` is a shared formatting
// helper.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons

Column {
  required property var panel

  id: toastStack
  z: 170
  anchors.right: parent.right
  anchors.bottom: parent.bottom
  anchors.rightMargin: 16
  anchors.bottomMargin: 16
  spacing: 8
  width: Math.min(360, parent.width - 32)

  Repeater {
    model: panel.toastItems || []
    delegate: Rectangle {
      id: toastItem
      required property var modelData
      required property int index
      width: toastStack.width
      radius: 10
      color: Qt.rgba(Color.menu.background.r, Color.menu.background.g, Color.menu.background.b, 0.97)
      border.color: panel.accentSoft(0.35)
      border.width: 1
      implicitHeight: toastItemLabel.implicitHeight + 18
      opacity: 0

      transform: Translate {
        id: toastSlide
        y: 14
      }

      Component.onCompleted: {
        opacity = 1;
        toastSlide.y = 0;
      }

      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }

      Timer {
        interval: 4200
        repeat: false
        running: true
        onTriggered: panel.removeToastById(toastItem.modelData.id)
      }

      Text {
        id: toastItemLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 10
        textFormat: Text.PlainText
        text: toastItem.modelData.text || ""
        color: Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.removeToastById(toastItem.modelData.id)
      }
    }
  }
}
