#!/usr/bin/env node
const fs = require("fs")
const path = require("path")

const root = path.join(__dirname, "..")
const modelDir = path.join(root, "model")

const order = [
  "text",
  "protocol",
  "format",
  "errors",
  "entities",
  "session",
  "presentation",
  "parse-doctor",
  "parse-devices",
  "parse-monitors",
  "parse-status",
  "cli",
  "panel-helpers"
]

function stripNode(src) {
  return src
    .replace(/^\.pragma library\s*\n/gm, "")
    .replace(/^\.import[^\n]*\n/gm, "")
    .replace(/^var \w+ = require\([^)]+\)\s*\n/gm, "")
    .replace(/\nmodule\.exports[\s\S]*$/m, "")
}

function rewriteRefs(src) {
  return src
    .replace(/\bText\.(\w+)/g, "$1")
    .replace(/\bProtocol\.(\w+)/g, "$1")
    .replace(/\bFormat\.(\w+)/g, "$1")
    .replace(/\bErrors\.(\w+)/g, "$1")
    .replace(/\bEntities\.(\w+)/g, "$1")
}

let bundle = ".pragma library\n\n"
for (const name of order) {
  let src = fs.readFileSync(path.join(modelDir, name + ".js"), "utf8")
  bundle += rewriteRefs(stripNode(src)) + "\n"
}

fs.writeFileSync(path.join(modelDir, "qml-bundle.js"), bundle)

const model = require(path.join(root, "FluxCastModel.node.js"))
const exportNames = Object.keys(model).sort()
const facade = ['.import "model/qml-bundle.js" as Bundle', ""]
for (const name of exportNames) {
  facade.push("function " + name + "(a,b,c,d,e,f) { return Bundle." + name + "(a,b,c,d,e,f) }")
  facade.push("")
}

fs.writeFileSync(path.join(root, "FluxCastModel.js"), facade.join("\n"))
console.log("Built FluxCastModel.js and model/qml-bundle.js")
