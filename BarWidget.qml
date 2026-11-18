import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "elena.vember-server-hub"

  readonly property var shellRoot: bar ? bar.shell : null
  readonly property bool hubOpen: shellRoot
    ? shellRoot.isPluginOpen("elena.vember-server-hub") === true : false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    bar: root.bar
    text: "󰒋"
    active: root.hubOpen
    tooltipText: root.hubOpen ? "Close Vember Server Hub" : "Open Vember Server Hub"
    onPressed: if (root.shellRoot) root.shellRoot.toggle("elena.vember-server-hub", "{}")
  }
}
