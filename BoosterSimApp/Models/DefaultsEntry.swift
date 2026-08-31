// DefaultsEntry.swift — Typed UserDefaults entry wrapper (plist value kinds + simctl argv fragment)
import Foundation

/// Typed plist value kinds the editor round-trips (CertificateStatus associated-value style).
/// `json` carries raw Data and nested/mixed plist values losslessly as a binary-plist capsule.
enum DefaultsEntryValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case array([String])
    case json(Data)

    /// Row-capsule label — the value KIND, never the value itself (values can be auth tokens, T-03-10).
    var typeLabel: String {
        switch self {
        case .string: return "string"
        case .int:    return "int"
        case .bool:   return "bool"
        case .array:  return "array"
        case .json:   return "json"
        }
    }

    /// Typed spawn-defaults flag + serialized value(s) — the unit-tested argv fragment
    /// (the service never string-builds inline). `-data` takes hex digits (`defaults help write`).
    var simctlTypeArg: [String] {
        switch self {
        case .string(let text):   return ["-string", text]
        case .int(let number):    return ["-int", String(number)]
        case .bool(let flag):     return ["-bool", flag ? "YES" : "NO"]
        case .array(let items):   return ["-array"] + items
        case .json(let payload):  return ["-data", payload.map { String(format: "%02x", $0) }.joined()]
        }
    }
}

/// One editable defaults key. Identifiable over the key; the row capsule shows the type only.
struct DefaultsEntry: Identifiable, Equatable, Sendable {
    let key: String
    let value: DefaultsEntryValue

    var id: String { key }

    /// Capsule label for the row (delegates to the typed value).
    var typeLabel: String { value.typeLabel }

    /// Write-argv fragment for this entry (delegates to the typed value).
    var simctlTypeArg: [String] { value.simctlTypeArg }
}
