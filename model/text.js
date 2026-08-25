// Shared string/JSON helpers used across parsers and CLI builders.
// Kept dependency-free so every model module can import it safely.

function normalizeText(value) {
  if (value === undefined || value === null) return ""
  return String(value).trim()
}

// Omarchy settings may arrive as strings ("true", "1", "on"); coerce to boolean.
function settingBool(value, fallback) {
  if (value === undefined || value === null || value === "") return !!fallback
  if (typeof value === "boolean") return value
  var text = String(value).trim().toLowerCase()
  return text === "1" || text === "true" || text === "yes" || text === "on"
}

function safeJson(raw) {
  var text = normalizeText(raw)
  if (text === "") return null
  try {
    return JSON.parse(text)
  } catch (e) {
    return null
  }
}

function arrayOf(value) {
  return Array.isArray(value) ? value : []
}

module.exports = {
  normalizeText: normalizeText,
  settingBool: settingBool,
  safeJson: safeJson,
  arrayOf: arrayOf
}
