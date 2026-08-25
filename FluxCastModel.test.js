const assert = require("assert")
const Model = require("./FluxCastModel.js")

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

console.log("ok")
