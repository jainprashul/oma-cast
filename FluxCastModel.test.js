const assert = require("assert")
const Model = require("./FluxCastModel.node.js")

assert.strictEqual(
  typeof Model.isSessionReadyLine,
  "function",
  "isSessionReadyLine should be exported so the panel can wait for a real session"
)

assert.strictEqual(
  Model.isSessionReadyLine("[FluxCast WFD RTSP] PLAY accepted; media stream started."),
  true,
  "WFD PLAY is a live session"
)

assert.strictEqual(
  Model.isSessionReadyLine("[FluxCast] Casting started. Press Ctrl+C to stop."),
  true,
  "Chromecast start is a live session"
)

assert.strictEqual(
  Model.isSessionReadyLine("[FluxCast] Output signal sent! The TV should open its native video player."),
  true,
  "DLNA output signal is a live session"
)

assert.strictEqual(
  Model.isSessionReadyLine("[FluxCast WFD] Connecting to Living Room via NetworkManager..."),
  false,
  "P2P connect is still connecting"
)

assert.strictEqual(
  Model.isSessionReadyLine("[FluxCast WFD RTSP] TV connected from 192.168.49.1; local=192.168.49.2"),
  false,
  "RTSP TCP connect is still handshake, not casting"
)

assert.strictEqual(
  Model.isSessionReadyLine("[FluxCast WFD] Waiting for TV RTSP/WFD session. Press Ctrl+C to stop."),
  false,
  "Waiting for RTSP is still connecting"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "scanning",
    running: true,
    sessionReady: true,
    fluxcastAvailable: true,
    action: "poll"
  }),
  "casting",
  "poll restores casting after a scan overwrites the live state"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "casting",
    running: false,
    sessionReady: true,
    fluxcastAvailable: true,
    action: "poll"
  }),
  "casting",
  "poll must not drop a live session if the process flag flickers"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "casting",
    running: true,
    sessionReady: true,
    fluxcastAvailable: true,
    action: "scan"
  }),
  "casting",
  "scan must not replace a connected session"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "idle",
    running: false,
    sessionReady: false,
    fluxcastAvailable: true,
    action: "scan"
  }),
  "scanning",
  "scan still enters scanning when idle"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "casting",
    running: true,
    sessionReady: true,
    fluxcastAvailable: false,
    action: "doctor-fail"
  }),
  "casting",
  "doctor failure must not kick a live session back to default"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "casting",
    running: false,
    sessionReady: true,
    fluxcastAvailable: true,
    action: "exit"
  }),
  "idle",
  "only an explicit exit leaves the connected state"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "scanning",
    running: false,
    sessionReady: false,
    scanInFlight: true,
    fluxcastAvailable: true,
    action: "poll"
  }),
  "scanning",
  "poll must not clear scanning while a scan is in flight"
)

assert.strictEqual(
  Model.barIcon(),
  "󰄘",
  "bar icon stays the cast glyph regardless of session state"
)

assert.notStrictEqual(
  Model.iconForState("unavailable"),
  "",
  "unavailable still has a bar glyph"
)

assert.strictEqual(
  Model.iconForState("idle"),
  "󰄘",
  "idle uses the Chromecast-style cast glyph, not the leftover arrow circle"
)

assert.notStrictEqual(
  Model.iconForState("idle"),
  "󰁐",
  "idle must not keep the arrow-circle glyph"
)

assert.strictEqual(
  Model.resolveSessionState({
    currentState: "unavailable",
    running: false,
    sessionReady: false,
    fluxcastAvailable: true,
    action: "poll"
  }),
  "idle",
  "successful doctor must leave unavailable so the idle icon can show"
)

assert.strictEqual(
  Model.defaultLogFile(),
  "/tmp/fluxcast-cast.log",
  "Log must open FluxCast's real session log, not a path FluxCast never writes"
)

assert.deepStrictEqual(
  Model.logPathsToOpen(""),
  ["/tmp/fluxcast-cast.log"],
  "empty config still opens the FluxCast session log"
)

assert.deepStrictEqual(
  Model.logPathsToOpen("/tmp/fluxcast-cast.log"),
  ["/tmp/fluxcast-cast.log"],
  "configured FluxCast log is not duplicated"
)

assert.deepStrictEqual(
  Model.logPathsToOpen("/home/pjain/.local/state/fluxcast/fluxcast.log"),
  ["/home/pjain/.local/state/fluxcast/fluxcast.log", "/tmp/fluxcast-cast.log"],
  "custom log-file is tried first, then the FluxCast session log"
)

assert.strictEqual(
  Model.canRestartProcess(false, false),
  true,
  "refresh can start when the previous doctor/monitor process has exited"
)

assert.strictEqual(
  Model.canRestartProcess(true, false),
  true,
  "refresh recovers when the in-flight flag stuck after the process died"
)

assert.strictEqual(
  Model.canRestartProcess(true, true),
  false,
  "refresh queues while a doctor/monitor process is still running"
)

console.log("ok")
