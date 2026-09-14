import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // ---- Estado general
  property bool initialized: false
  property bool connected: false
  property bool refreshing: false
  property bool busy: statusProc.running || actionProc.running

  property bool soundEnabled: true

  property string name: "WLmouse"
  property string firmware: ""
  property string dongleFirmware: ""
  property int battery: -1
  property bool charging: false
  property int activeProfile: -1

  // Dispositivos (wl-mouse -j list)
  property var devices: []               // [{name,pid,path}]
  property string selectedDevice: ""     // "" = auto-detect

  // Perfil ACTIVO (wl-mouse -j profile)
  property int pollingRateHz: -1
  property var dpiStages: []             // [{stage,x,y,active}]
  property int activeDpiStage: -1
  property real lodMm: -1                // 0.7/1/2
  property int debounceMs: -1
  property bool angleSnap: false
  property bool motionSync: false
  property int angleTune: 0
  property bool rippleControl: false
  property int sleepMinutes: -1

  property string lastError: ""

  // Captura de salida de comandos (para diagnosticar fallos)
  property string actionOut: ""
  property string actionErr: ""

  // ---- Notificaciones batería baja
  property int lowBatteryThreshold: 25
  property int criticalBatteryThreshold: 15
  property int notifyCooldownMs: 30 * 60 * 1000
  property int criticalNotifyCooldownMs: 10 * 60 * 1000
  property double _lastNotifyMs: 0
  property double _lastCriticalNotifyMs: 0
  property int _lastBatterySeen: -1

  readonly property string home: Quickshell.env("HOME") || ""

  readonly property var helperEnvironment: ({
    "PATH": home + "/.local/bin:" + home + "/.cargo/bin:/usr/bin:/bin",
    "HOME": home,
    "USER": Quickshell.env("USER") || "",
    "XDG_RUNTIME_DIR": Quickshell.env("XDG_RUNTIME_DIR") || "",
    "DBUS_SESSION_BUS_ADDRESS": Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || "",
    "LANG": Quickshell.env("LANG") || "C"
  })
  function runWlMouse(args, jsonMode) {
    // Si 3s te daba problemas, súbelo; lo dejo en 8 para ser más robusto
    var cmd = ["/usr/bin/timeout", "-s", "KILL", "8", "wl-mouse"]
    if (selectedDevice && String(selectedDevice).trim() !== "") {
      cmd.push("-d")
      cmd.push(String(selectedDevice).trim())
    }
    if (jsonMode === true) cmd.push("-j")
    for (var i = 0; i < args.length; i++) cmd.push(String(args[i]))
    return cmd
  }

  function selectDevice(path) {
    selectedDevice = String(path || "").trim()
    refresh()
  }

  // ---- Helpers de update optimista
  function _setDpiStageLocal(stage, dpi) {
    var st = parseInt(stage, 10)
    var d = parseInt(dpi, 10)
    if (!isFinite(st) || st < 1) return
    if (!isFinite(d) || d < 50) return

    var arr = (dpiStages instanceof Array) ? dpiStages : []
    var out = []
    for (var i = 0; i < arr.length; i++) {
      var row = arr[i]
      if (!row) continue
      if (row.stage === st) out.push({ stage: row.stage, x: d, y: d, active: row.active === true })
      else out.push({ stage: row.stage, x: row.x, y: row.y, active: row.active === true })
    }
    dpiStages = out
  }

  function _setActiveStageLocal(stage) {
    var st = parseInt(stage, 10)
    if (!isFinite(st) || st < 1) return
    activeDpiStage = st
    var arr = (dpiStages instanceof Array) ? dpiStages : []
    var out = []
    for (var i = 0; i < arr.length; i++) {
      var row = arr[i]
      if (!row) continue
      out.push({ stage: row.stage, x: row.x, y: row.y, active: row.stage === st })
    }
    dpiStages = out
  }

  // ---- Setters
  // Compatibles con firma (hz) o (profileId, hz)
  function setPollingRate(a, b) {
    if (actionProc.running) return
    var hz = (b === undefined) ? a : b
    var n = parseInt(hz, 10)
    if (!isFinite(n) || n <= 0) return
    pollingRateHz = n
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["polling-rate", String(n)], false)
    actionProc.running = true
  }

  // Compatibles con firma (mm) o (profileId, mm)
  function setLod(a, b) {
    if (actionProc.running) return
    var mm = (b === undefined) ? a : b
    var v = String(mm)
    lodMm = parseFloat(v)
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["lod", v], false)
    actionProc.running = true
  }

  function setDebounce(ms) {
    if (actionProc.running) return
    var n = parseInt(ms, 10)
    if (!isFinite(n) || n < 0) return
    debounceMs = n
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["debounce", String(n)], false)
    actionProc.running = true
  }

  function setAngleSnap(on) {
    if (actionProc.running) return
    angleSnap = (on === true)
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["angle-snap", angleSnap ? "on" : "off"], false)
    actionProc.running = true
  }

  function setMotionSync(on) {
    if (actionProc.running) return
    motionSync = (on === true)
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["motion-sync", motionSync ? "on" : "off"], false)
    actionProc.running = true
  }

  function setRippleControl(on) {
    if (actionProc.running) return
    rippleControl = (on === true)
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["ripple-control", rippleControl ? "on" : "off"], false)
    actionProc.running = true
  }

  function setAngleTune(v) {
    if (actionProc.running) return
    var n = parseInt(v, 10)
    if (!isFinite(n)) return
    angleTune = n
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["angle-tune", String(n)], false)
    actionProc.running = true
  }

  function setSleepMinutes(minutes) {
    if (actionProc.running) return
    var n = parseInt(minutes, 10)
    if (!isFinite(n) || n < 0) return
    sleepMinutes = n
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["sleep-time", String(n)], false)
    actionProc.running = true
  }

  function setActiveStage(stage) {
    if (actionProc.running) return
    _setActiveStageLocal(stage)
    lastError = ""
    actionOut = ""; actionErr = ""
    actionProc.command = runWlMouse(["dpi", "active", String(stage)], false)
    actionProc.running = true
  }

  function setDpiStage(stage, dpi) {
    if (actionProc.running) return
    _setDpiStageLocal(stage, dpi)
    lastError = ""
    actionOut = ""; actionErr = ""
    // help: wl-mouse dpi set -s 2 800
    actionProc.command = runWlMouse(["dpi", "set", "-s", String(stage), String(dpi)], false)
    actionProc.running = true
  }

  // ---- Refresh queue
  property var _queue: []
  property string _kind: ""
  property bool _required: false
  property string _out: ""
  property string _err: ""

  function refresh() {
    if (statusProc.running) return
    refreshing = true
    lastError = ""
    _queue = [
      { kind: "list", required: false, args: ["list"], json: true },
      { kind: "info", required: true,  args: ["info"], json: true },
      { kind: "profile", required: false, args: ["profile"], json: true }
    ]
    _runNext()
  }

  function _runNext() {
    if (_queue.length === 0) {
      refreshing = false
      initialized = true
      return
    }
    var job = _queue.shift()
    _kind = job.kind
    _required = job.required === true
    _out = ""
    _err = ""
    statusProc.command = runWlMouse(job.args, job.json === true)
    statusProc.running = true
  }

  function _notifyLowBatteryIfNeeded() {
    if (!connected) return
    if (charging) return
    if (battery < 0) return

    var crossedLow = (_lastBatterySeen >= 0 && _lastBatterySeen > lowBatteryThreshold && battery <= lowBatteryThreshold)
                  || (_lastBatterySeen < 0 && battery <= lowBatteryThreshold)
    var crossedCritical = (_lastBatterySeen >= 0 && _lastBatterySeen > criticalBatteryThreshold && battery <= criticalBatteryThreshold)
                       || (_lastBatterySeen < 0 && battery <= criticalBatteryThreshold)

    _lastBatterySeen = battery
    var now = Date.now()

    if (crossedLow && (now - _lastNotifyMs >= notifyCooldownMs)) {
      _lastNotifyMs = now
      _sendBatteryNotification("Batería al " + battery + "%", "Queda poca batería en " + name, "normal")
    }

    if (crossedCritical && (now - _lastCriticalNotifyMs >= criticalNotifyCooldownMs)) {
      _lastCriticalNotifyMs = now
      _sendBatteryNotification("¡Batería crítica! " + battery + "%", "Conecta el ratón " + name + " para cargarlo", "critical")
    }
  }

  function _sendBatteryNotification(title, body, urgency) {
    if (!notifyProc.running) {
      notifyProc.command = ["/usr/bin/notify-send", "-u", urgency, title, body]
      notifyProc.running = true
    }
    _playNotificationSound(urgency === "critical")
  }

  function _playNotificationSound(isCritical) {
    if (!soundEnabled) return
    if (soundProc.running) return

    var soundFile = isCritical
      ? "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
      : "/usr/share/sounds/freedesktop/stereo/complete.oga"

    soundProc.command = ["/usr/bin/paplay", soundFile]
    soundProc.running = true
  }

  function _parseListJson(obj) {
    if (!(obj instanceof Array)) return
    var out = []
    for (var i = 0; i < obj.length; i++) out.push(obj[i])
    devices = out
  }

  function _parseInfoJson(obj) {
    name = String(obj.name || "WLmouse")
    firmware = String(obj.firmware || "")
    dongleFirmware = String(obj.dongle_firmware || "")
    battery = (obj.battery_percent === undefined || obj.battery_percent === null) ? -1 : parseInt(obj.battery_percent, 10)
    charging = obj.charging === true
    activeProfile = (obj.active_profile === undefined || obj.active_profile === null) ? -1 : parseInt(obj.active_profile, 10)
    connected = true
    _notifyLowBatteryIfNeeded()
  }

  function _parseProfileJson(obj) {
    pollingRateHz = parseInt(obj.polling_rate_hz || 0, 10)
    lodMm = (obj.lod_mm === undefined || obj.lod_mm === null) ? -1 : parseFloat(obj.lod_mm)
    debounceMs = parseInt(obj.debounce_ms || 0, 10)
    angleSnap = obj.angle_snap === true
    motionSync = obj.motion_sync === true
    angleTune = parseInt(obj.angle_tune || 0, 10)
    rippleControl = obj.ripple_control === true

    var sleepSec = parseInt(obj.sleep_time_seconds || 0, 10)
    sleepMinutes = isFinite(sleepSec) ? Math.round(sleepSec / 60) : -1

    var stages = []
    var active = -1
    var rawStages = (obj.dpi_stages instanceof Array) ? obj.dpi_stages : []
    for (var i = 0; i < rawStages.length; i++) {
      var row = rawStages[i] || {}
      var stNum = i + 1
      var x = parseInt(row.x || 0, 10)
      var y = parseInt(row.y || 0, 10)
      var act = row.active === true
      if (act) active = stNum
      stages.push({ stage: stNum, x: x, y: y, active: act })
    }
    dpiStages = stages
    activeDpiStage = active

    if (obj.id !== undefined && obj.id !== null) {
      var pid = parseInt(obj.id, 10)
      if (isFinite(pid) && pid > 0) activeProfile = pid
    }

    connected = true
  }

  Timer {
    interval: 300000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    running: false
    command: []
    clearEnvironment: true
    environment: root.helperEnvironment
    stdout: SplitParser { splitMarker: ""; onRead: function(data) { root._out += data } }
    stderr: SplitParser { splitMarker: ""; onRead: function(data) { root._err += data } }

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (root._required) {
          root.connected = false
          root.lastError = root._err || root._out || ("wl-mouse falló (" + exitCode + ")")
          root.refreshing = false
          root.initialized = true
          return
        }
        root._runNext()
        return
      }

      var text = String(root._out || "").trim()
      if (text === "") { root._runNext(); return }

      var parsed = null
      try { parsed = JSON.parse(text) } catch (e) {
        if (root._required) root.lastError = "No se pudo parsear JSON de wl-mouse (" + root._kind + ")"
        root._runNext()
        return
      }

      if (root._kind === "list") root._parseListJson(parsed)
      else if (root._kind === "info") root._parseInfoJson(parsed)
      else if (root._kind === "profile") root._parseProfileJson(parsed)

      root._runNext()
    }
  }

  Process {
    id: actionProc
    running: false
    command: []
    clearEnvironment: true
    environment: root.helperEnvironment
    stdout: SplitParser { splitMarker: ""; onRead: function(d) { root.actionOut += d } }
    stderr: SplitParser { splitMarker: ""; onRead: function(d) { root.actionErr += d } }

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = root.actionErr || root.actionOut || ("wl-mouse command failed (" + exitCode + ")")
      }
      root.refresh()
    }
  }

  Process {
    id: soundProc
    running: false
    command: []
    clearEnvironment: true
    environment: root.helperEnvironment
    onExited: function(_) { soundProc.running = false }
  }

  Process {
    id: notifyProc
    running: false
    command: []
    clearEnvironment: true
    environment: root.helperEnvironment
  }
}