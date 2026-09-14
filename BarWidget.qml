import QtQuick
import qs.Commons
import qs.Ui
import Quickshell.Io
import Quickshell

BarWidget {
  id: root
  moduleName: "omarchy-wlmouse"

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property bool ready: !!svc && svc.initialized === true
  readonly property bool connected: ready && svc.connected === true
  readonly property int battery: ready ? svc.battery : -1

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  readonly property string webAppUrl: "https://gm.wlmouse.gg/#/project/items"
  function openWebApp() {
    if (webappProc.running) return
    // Opción A: usando omarchy
    webappProc.command = ["omarchy-launch-webapp", webAppUrl]
    webappProc.running = true
    
  }
  Process {
    id: webappProc
    running: false
    command: []
    clearEnvironment: false
    environment: ({
      "PATH": (Quickshell.env("HOME") || "") + "/.local/bin:/usr/bin:/bin",
      "HOME": Quickshell.env("HOME") || "",
      "USER": Quickshell.env("USER") || "",
      "DBUS_SESSION_BUS_ADDRESS": Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || ""
    })
    onExited: function(_) { webappProc.running = false }
  }

  // Altura y tamaños derivados del estilo (no del botón)
  readonly property int rowH: Math.round(Style.font.body * 1.65)
  readonly property int iconPx: Math.round(rowH * 0.70)
  readonly property int batteryPx: Math.round(rowH * 0.55)

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  Component.onCompleted: Qt.callLater(injectPanel)

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: root.injectPanel()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    dimmed: !root.connected

    tooltipText: (root.svc && root.connected)
      ? (String(root.svc.name || "WLmouse") +
         (root.battery >= 0 ? " · " + root.battery + "%" : "") +
         (root.svc.pollingRateHz > 0 ? " · " + root.svc.pollingRateHz + "Hz" : ""))
      : "WLmouse — offline"

    fixedWidth: root.vertical ? -1 : Math.round(content.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.round(content.implicitHeight + scaledVerticalPadding * 2) : -1
    
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.openWebApp()
      else if (buttonCode === Qt.MiddleButton && root.svc) root.svc.refresh()
      else root.toggle()
    }

    Item {
      id: content
      anchors.centerIn: parent
      implicitWidth: row.implicitWidth
      implicitHeight: root.rowH
      width: implicitWidth
      height: implicitHeight

      Row {
        id: row
        spacing: Style.space(4)
        anchors.centerIn: parent

        // ICONO (centrado y con altura fija)
        Item {
          height: root.rowH
          implicitHeight: root.rowH
          width: iconText.implicitWidth
          Text {
            id: iconText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "󰍽"
            color: button.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.iconPx
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize
            opacity: root.connected ? 1 : 0.45
          }
        }

        // BATERÍA (centrada y escalable)
        Item {
          visible: root.battery >= 0 && !root.vertical
          height: root.rowH
          implicitHeight: root.rowH
          width: batteryText.implicitWidth
          Text {
            id: batteryText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.battery + "%"
            color: (root.battery >= 0 && root.battery <= 25)
              ? (root.bar && root.bar.urgent ? root.bar.urgent : button.foreground)
              : button.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: root.batteryPx
            font.bold: true
            lineHeightMode: Text.FixedHeight
            lineHeight: font.pixelSize
            opacity: root.connected ? 1 : 0.45
          }
        }
      }
    }
  }
}
