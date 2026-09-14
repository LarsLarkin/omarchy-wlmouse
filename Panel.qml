pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omarchy-wlmouse"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var svc: (bar && bar.shell) ? bar.shell.serviceFor(moduleName) : null
  readonly property var devicesList: (svc && svc.devices instanceof Array) ? svc.devices : []

  readonly property bool ready: !!svc && svc.initialized === true
  readonly property bool connected: ready && svc.connected === true

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string sleepDraft: "0"
  property string angleTuneDraft: "0"

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { opened ? close() : open() }

  function lodValueText() {
    if (!svc || svc.lodMm <= 0) return ""
    if (Math.abs(svc.lodMm - 0.7) < 0.01) return "0.7"
    if (Math.abs(svc.lodMm - 1.0) < 0.01) return "1"
    if (Math.abs(svc.lodMm - 2.0) < 0.01) return "2"
    return String(svc.lodMm)
  }

  onOpenedChanged: {
    if (opened && svc) svc.refresh()
    if (opened && svc) {
      sleepDraft = svc.sleepMinutes >= 0 ? String(svc.sleepMinutes) : "0"
      angleTuneDraft = String(svc.angleTune || 0)
    }
  }

  Connections {
    target: svc
    function onSleepMinutesChanged() {
      if (!sleepInput.activeFocus) root.sleepDraft = (svc.sleepMinutes >= 0 ? String(svc.sleepMinutes) : "0")
    }
    function onAngleTuneChanged() {
      if (!angleTuneInput.activeFocus) root.angleTuneDraft = String(svc.angleTune || 0)
    }
  }

  KeyboardPanel {
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    padding: Style.space(14)
    contentWidth: fittedContentWidth(Style.space(420))
    contentHeight: fittedContentHeight(column.implicitHeight, Style.space(880))

    Item {
      anchors.fill: parent
      clip: true

      // Fondo opaco para evitar “transparencia”
      Rectangle {
        anchors.fill: parent
        color: "#141414"
        opacity: 0.94
        z: -1
      }

      PanelKeyCatcher {
        anchors.fill: parent
        onCloseRequested: root.close()

        Flickable {
          anchors.fill: parent
          contentWidth: width
          contentHeight: column.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          flickableDirection: Flickable.VerticalFlick

          Column {
            id: column
            width: parent.width
            spacing: Style.space(12)

            PanelHero {
              width: parent.width
              title: root.ready ? (root.svc.name || "WLmouse") : "WLmouse"
              meta: root.connected
                ? ((root.svc.battery >= 0 ? root.svc.battery + "% · " : "") +
                   (root.svc.charging ? "charging · " : "") +
                   (root.svc.activeProfile > 0 ? ("profile " + root.svc.activeProfile + " · ") : "") +
                   (root.svc.pollingRateHz > 0 ? (root.svc.pollingRateHz + "Hz") : "connected"))
                : "Offline"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: root.connected ? 1 : 0.45
              iconComponent: Component {
                Text {
                  textFormat: Text.PlainText
                  text: "󰍽"
                  color: root.foreground
                  font.pixelSize: Style.font.display
                  lineHeightMode: Text.FixedHeight
                  lineHeight: font.pixelSize
                }
              }
            }

            Text {
              visible: root.svc && root.svc.lastError !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: root.svc ? root.svc.lastError : ""
              color: bar && bar.urgent ? bar.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            // Devices
            Column {
              width: parent.width
              spacing: Style.space(6)
              visible: root.devicesList.length > 0

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Devices"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Repeater {
                model: root.devicesList.length
                Button {
                  required property int index
                  readonly property var dev: root.devicesList[index]
                  width: parent.width
                  text: (dev && dev.name ? dev.name : "") + (dev && dev.path ? ("  (" + dev.path + ")") : "")
                  selected: !!(root.svc && dev && String(dev.path) === String(root.svc.selectedDevice))
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: if (root.svc && dev) root.svc.selectDevice(dev.path)
                }
              }
            }

            // Polling rate (Dropdown “como el que te funcionaba”)
            Dropdown {
              visible: root.connected
              width: parent.width
              label: "Polling rate"
              value: root.svc && root.svc.pollingRateHz > 0 ? String(root.svc.pollingRateHz) : ""
              options: [
                { value: "125", label: "125 Hz" },
                { value: "250", label: "250 Hz" },
                { value: "500", label: "500 Hz" },
                { value: "1000", label: "1000 Hz" },
                { value: "2000", label: "2000 Hz" },
                { value: "4000", label: "4000 Hz" },
                { value: "8000", label: "8000 Hz" }
              ]
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { if (root.svc) root.svc.setPollingRate(parseInt(v, 10)) }
            }

            // LOD (Dropdown 0.7/1/2)
            Dropdown {
              visible: root.connected
              width: parent.width
              label: "LOD"
              value: root.lodValueText()
              options: [
                { value: "0.7", label: "0.7 mm" },
                { value: "1", label: "1 mm" },
                { value: "2", label: "2 mm" }
              ]
              foreground: root.foreground
              fontFamily: root.fontFamily
              onChanged: function(v) { if (root.svc) root.svc.setLod(v) }
            }

            Toggle {
              visible: root.connected
              width: parent.width
              label: "Angle snap"
              checked: !!(root.svc && root.svc.angleSnap)
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.svc) root.svc.setAngleSnap(!root.svc.angleSnap)
            }

            Toggle {
              visible: root.connected
              width: parent.width
              label: "Motion sync"
              checked: !!(root.svc && root.svc.motionSync)
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.svc) root.svc.setMotionSync(!root.svc.motionSync)
            }

            Toggle {
              visible: root.connected
              width: parent.width
              label: "Ripple control"
              checked: !!(root.svc && root.svc.rippleControl)
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: if (root.svc) root.svc.setRippleControl(!root.svc.rippleControl)
            }

            // Angle tune
            Column {
              visible: root.connected
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Angle tune"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Rectangle {
                  width: parent.width * 0.65
                  height: Style.space(34)
                  radius: Style.space(8)
                  color: Qt.rgba(1,1,1,0.06)
                  border.width: 1
                  border.color: Qt.rgba(1,1,1,0.12)

                  TextInput {
                    id: angleTuneInput
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    color: root.foreground
                    font.pixelSize: Style.font.body
                    font.family: root.fontFamily
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: root.angleTuneDraft
                    validator: IntValidator { bottom: -100; top: 100 }
                    onTextChanged: root.angleTuneDraft = text
                    onAccepted: angleTuneApply.clicked()
                  }
                }

                Button {
                  id: angleTuneApply
                  width: parent.width * 0.35 - parent.spacing
                  text: "Apply"
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: {
                    if (!root.svc) return
                    var v = parseInt(root.angleTuneDraft, 10)
                    if (!isFinite(v)) return
                    root.svc.setAngleTune(v)
                    angleTuneInput.focus = false
                  }
                }
              }
            }

            // Sleep time (minutes, 0 = off)
            Column {
              visible: root.connected
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Sleep time (minutes, 0 = off)"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Rectangle {
                  width: parent.width * 0.65
                  height: Style.space(34)
                  radius: Style.space(8)
                  color: Qt.rgba(1,1,1,0.06)
                  border.width: 1
                  border.color: Qt.rgba(1,1,1,0.12)

                  TextInput {
                    id: sleepInput
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    color: root.foreground
                    font.pixelSize: Style.font.body
                    font.family: root.fontFamily
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: root.sleepDraft
                    validator: IntValidator { bottom: 0; top: 999 }
                    onTextChanged: root.sleepDraft = text
                    onAccepted: sleepApply.clicked()
                  }
                }

                Button {
                  id: sleepApply
                  width: parent.width * 0.35 - parent.spacing
                  text: "Apply"
                  bordered: true
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: {
                    if (!root.svc) return
                    var v = parseInt(root.sleepDraft, 10)
                    if (!isFinite(v)) return
                    root.svc.setSleepMinutes(v)
                    sleepInput.focus = false
                  }
                }
              }
            }
            
            // DPI stages (si tu Service expone setDpiStage / setActiveStage)
            Column {
              visible: root.connected && root.svc && root.svc.dpiStages && root.svc.dpiStages.length > 0
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "DPI stages"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Repeater {
                model: root.svc && root.svc.dpiStages ? root.svc.dpiStages.length : 0

                Row {
                  required property int index
                  readonly property var st: root.svc.dpiStages[index]
                  property string dpiDraft: st ? String(st.x) : "0"

                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    width: parent.width * 0.16
                    textFormat: Text.PlainText
                    text: st ? ("S" + st.stage + (st.active ? "*" : "")) : ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: st && st.active
                  }

                  Button {
                    width: parent.width * 0.22
                    text: "Active"
                    bordered: true
                    selected: st && st.active
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onClicked: if (root.svc && st) root.svc.setActiveStage(st.stage)
                  }

                  Rectangle {
                    width: parent.width * 0.32
                    height: Style.space(34)
                    radius: Style.space(8)
                    color: Qt.rgba(1,1,1,0.06)
                    border.width: 1
                    border.color: Qt.rgba(1,1,1,0.12)

                    TextInput {
                      anchors.fill: parent
                      anchors.margins: Style.space(8)
                      color: root.foreground
                      font.pixelSize: Style.font.body
                      font.family: root.fontFamily
                      inputMethodHints: Qt.ImhDigitsOnly
                      text: dpiDraft
                      validator: IntValidator { bottom: 50; top: 30000 }
                      onTextChanged: dpiDraft = text
                      onAccepted: applyBtn.clicked()
                    }
                  }

                  Button {
                    id: applyBtn
                    width: parent.width * 0.22 - parent.spacing
                    text: "Apply"
                    bordered: true
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    onClicked: {
                      if (!root.svc || !st) return
                      var v = parseInt(dpiDraft, 10)
                      if (!isFinite(v)) return
                      root.svc.setDpiStage(st.stage, v)
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
}