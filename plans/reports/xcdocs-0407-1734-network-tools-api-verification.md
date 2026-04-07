# Network Tools — Apple API Verification (xcdocs)

**Date:** 2026-04-07
**Source:** xcdocs (local Apple developer documentation)
**Scope:** Verify all Apple APIs referenced in Network Tools sub-issues #6–#10

---

## Verified Symbols

| Symbol | Framework | Status | Notes |
|--------|-----------|:------:|-------|
| `NWListener` | Network | ✅ Confirmed | `init(using: NWParameters, on: NWEndpoint.Port = .any) throws` |
| `NWConnection` | Network | ✅ Confirmed | `final class NWConnection`, Sendable, has `init(host:port:using:)` |
| `NEFilterDataProvider` | NetworkExtension | ✅ Confirmed | Requires Network Extensions + Content Filter capability |
| `NETransparentProxyProvider` | NetworkExtension | ✅ Confirmed | Subclass of `NEAppProxyProvider`; "connect by name" flows still use DNS |
| `SMAppService` | ServiceManagement | ✅ Confirmed | macOS 13+ replacement for SMJobBless |

---

## ❗ CRITICAL FINDING: SMJobBless Deprecated

**Sub-issue #7 must be updated.** The brainstorm report referenced `SMJobBless` for the privileged helper installation, but Apple's docs state:

> "Prior to macOS 13, part of the application-design process of helper executables included scripts that installed one or more property lists into specific directories."
> "In macOS 13 and later, a new structure in the app bundle simplifies the installation of these login items and associated property lists."

**Modern API:** `SMAppService.daemon(plistName:)` + `register()` / `unregister()`

```swift
import ServiceManagement

let helper = SMAppService.daemon(plistName: "com.boostersim.throttle.helper.plist")
try helper.register()  // Triggers user approval in System Settings
// ...
try helper.unregister()
```

**Why this matters for BoosterSimApp:**
- Project targets **macOS 15+** → SMJobBless is fully obsolete here
- `SMAppService` requires `LaunchDaemons/<plistName>` inside `Contents/` of app bundle
- User approval flows through **System Settings → Login Items & Extensions**, not legacy auth dialogs
- Simpler bundle structure: no helper installer scripts

---

## NWListener API (verified)

```swift
init(using: NWParameters, on: NWEndpoint.Port = .any) throws
```

Confirmed signature for proxy implementation in #6. Use `NWParameters.tcp` for TCP listener, port `8888`.

---

## NWConnection API (verified)

Key methods/initializers for proxy forwarding:
- `convenience init(host: NWEndpoint.Host, port: NWEndpoint.Port, using: NWParameters)`
- `init(to: NWEndpoint, using: NWParameters)`
- `func start(queue: DispatchQueue)`
- `func cancel()` / `func forceCancel()`
- `var stateUpdateHandler: ((NWConnection.State) -> Void)?`

Class is **`final class NWConnection`** and conforms to `Sendable` — safe for Swift 6 strict concurrency.

---

## NEFilterDataProvider — Confirmed Constraints

Verifies the brainstorm's "rejected" rationale for #4:

- **Requires Network Extensions capability + Content Filter sub-capability** (entitlement)
- Operates on `NEFilterFlow` objects (not raw packets)
- Filter Data Provider extension is **sandboxed** — cannot move network content outside its address space
- Has 6 callbacks for inbound/outbound data + handleNewFlow + handleRemediation
- Implementation must be a **separate extension target**, not main app

**Decision unchanged:** Network Extension is too heavy for MVP. Proxy approach (#6) remains correct.

---

## NETransparentProxyProvider — Important Behavior Notes

- Inherits from `NEAppProxyProvider`
- Returning `false` from `handleNewFlow` → flow proceeds to **direct destination** (NOT "Connection Refused" like NEAppProxyProvider)
- **Ignores** `NEDNSSettings` and `NEProxySettings` in `NETransparentProxyNetworkSettings`
- Network.framework / URLSession flows that match `includedNetworkRules` still use DNS resolution
- Configurable via `NETransparentProxyNetworkSettings.includedNetworkRules`

**Implication:** If we ever revisit Network Extension approach, `NETransparentProxyProvider` is more flexible than `NEFilterDataProvider` for our use case (we want to inspect/modify, not just filter).

---

## Not in xcdocs (Shell tools — verified externally)

| Tool | Purpose | Status |
|------|---------|:------:|
| `xcrun simctl keychain` | Cert install/reset | ✅ Verified via `xcrun simctl help` |
| `networksetup -setwebproxy` | System proxy toggle | ✅ Standard macOS, exists |
| `pfctl` | Packet filter rules | ✅ Standard BSD, ships with macOS |
| `dnctl` | Dummynet pipe config | ✅ Standard BSD, ships with macOS |
| `openssl` (LibreSSL) | CA cert generation | ✅ Ships with macOS |

These are CLI tools, not framework APIs — no xcdocs entries expected.

---

## Required Sub-Issue Updates

### Sub-issue #7 (Speed Control / Throttle)

**Current text references:** `SMJobBless` (deprecated)
**Replace with:** `SMAppService.daemon(plistName:)` (macOS 13+)

Updated service design:
```
NetworkThrottleService (@MainActor, ObservableObject)
├── @Published activeProfile: ThrottleProfile?
├── helper: SMAppService = .daemon(plistName: "com.boostersim.throttle.helper.plist")
├── installHelper() throws → helper.register()
├── uninstallHelper() throws → helper.unregister()
├── XPC connection to helper for dnctl/pfctl commands
└── auto-cleanup on app quit
```

Bundle structure required:
```
BoosterSimApp.app/Contents/
├── MacOS/BoosterSimApp
└── LaunchDaemons/
    └── com.boostersim.throttle.helper.plist
```

User approval flow:
1. User clicks "Apply Throttle" → `helper.register()`
2. System shows notification: "BoosterSimApp added items that can run in the background"
3. User must approve in **System Settings → General → Login Items & Extensions → Allow in the Background**
4. Helper runs as launchd daemon under `_root`, exposes XPC to main app

---

## Other Sub-Issues — No Changes Required

| Issue | API References | Status |
|-------|---------------|:------:|
| #6 (Traffic Monitor) | `NWListener`, `NWConnection`, `networksetup` | ✅ All verified |
| #8 (Airplane Mode) | (proxy infra only) | ✅ Verified |
| #9 (Request Blocking) | (proxy infra + `@AppStorage`) | ✅ Verified |
| #10 (Cert Trust) | `xcrun simctl keychain`, `openssl` CLI | ✅ Verified |

---

## Unresolved Questions

1. **SMAppService user approval UX:** Does macOS 15+ show the approval prompt synchronously after `register()`, or only on first daemon launch attempt? Need to test.
2. **XPC validation:** The Proxyman HelperTool advisory (NCC Group) showed insufficient XPC validation as a security risk. What's the modern best practice for validating XPC clients with `SMAppService`-managed daemons? (`SecCodeCopyGuestWithAttributes` + entitlement check)
3. **Helper plist location:** Confirm whether `Contents/Library/LaunchDaemons/` or `Contents/LaunchDaemons/` is the correct path for `SMAppService.daemon(plistName:)`.
