# Phase 3: App Actions - Pattern Map

**Mapped:** 2026-08-31
**Files analyzed:** 28 (18 new, 4 modified, 6 Wave 0 tests)
**Analogs found:** 28 / 28 (4 with flagged partial/no-analog sub-parts — see No Analog Found)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality | Drift Risk |
|-------------------|------|-----------|----------------|---------------|------------|
| `BoosterSimApp/Services/AppActionService.swift` | service (facade) | request-response (state machine over simctl verbs) | `BoosterSimApp/Services/CertificateService.swift` | exact | Skipping the `begin/finish/fail/transition` quartet; spawning `Process` directly instead of `simCtl.run` |
| `BoosterSimApp/Services/DerivedDataAppScanner.swift` | service (scanner) | batch (FS walk → models) | `BoosterSimApp/Services/XcodeDetector.swift` | role-match | Making it a stateful `ObservableObject` instead of a pure enum; hardcoding this project's DerivedData path |
| `BoosterSimApp/Services/UserDefaultsEditorService.swift` | service | CRUD (plist read + spawn write) | `BoosterSimApp/Services/EnvironmentOverrideService.swift` | exact (spawn defaults is its home turf) | Building on `defaults export` (silently unsupported — RESEARCH Pitfall 5); logging values |
| `BoosterSimApp/Services/SimCtlService.swift` (modify) | service (seam EXTEND) | request-response (subprocess) | self | self | Keeping the `waitUntilExit`-then-`readDataToEndOfFile` order (deadlock, RESEARCH Pitfall 2); adding async/await while touching it |
| `BoosterSimApp/Models/AppAction.swift` | model | transform (pure search/filter) | `TrafficFilter` in `BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift:45-62` | exact | Hiding search in the view instead of a pure `matches`-style struct; making `EffectLatency` a free String |
| `BoosterSimApp/Models/PushPayload.swift` | model | transform (Codable + validation) | `BoosterCommand`/`ThrottleSpec` in `BoosterSimApp/Models/BoosterCommand.swift:18-46` + `BlockRule` validation style | role-match | Encoding without the 4096-byte/object-shape gate; trusting `defaults export`-like silent failures |
| `BoosterSimApp/Models/PrivacyPermission.swift` | model | transform (enum → verbatim strings) | `SideWindowPosition` in `BoosterSimApp/Models/AppSettings.swift:9-16` + `HTTPMethod` in `NetworkEventModel.swift:6-13` | exact | Treating service strings as editable — they are a simctl contract to lock verbatim; inventing a `notifications` case |
| `BoosterSimApp/Models/DefaultsEntry.swift` | model | transform (typed wrapper) | `CertificateStatus` in `BoosterSimApp/Services/CertificateModels.swift:1-30` | role-match | Collapsing typed cases into `String` values; forgetting the array/JSON cases |
| `BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift:15-62` | role-match | Auto-guessing the "active" app (no frontmost verb — RESEARCH Pitfall 11); non-token row heights |
| `BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift` | exact | Filtering in the view body instead of through `AppActionCatalog.filter(query:)` |
| `BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` | exact | Omitting the destructive `confirmationDialog` or naming the wrong blast radius (device-wide, not per-app) |
| `BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/DeepLinkSectionView.swift` | exact (input + presets + result caption shape) | Copying DeepLinkSectionView's raw `12/8/6` spacing (flagged conventions deviation) instead of tokens |
| `BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` | exact (pills + honest scope caption) | Shipping a fake notifications toggle; skipping the PRO-01-style caption (D-01) |
| `BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift` | exact (same service family: spawn defaults + device state) | Writing locale keys without the relaunch caption/step (looks like a no-op — RESEARCH Pitfall 6) |
| `BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift:101-151` (validated add-row + captions) | role-match | Leaving `location start` without a visible Stop (`location clear` — RESEARCH Pitfall 10) |
| `BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift` | component | request-response (UI) | `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift:4-20` | role-match | Building a background auto-sync timer instead of two explicit buttons (RESEARCH clipboard tradeoffs) |
| `BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift` | component | CRUD (editor UI) | `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` | exact (list + toggle + delete + add + cap captions) | Editing values directly in the row instead of via service write path; showing values in logs |
| `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` (modify) | component | request-response (UI) | self — existing mount point (`CaptureTabView` body shows the multi-section shell) | self | Restructuring existing sections (EnvironmentOverridesView + DeepLinkSectionView stay untouched at top) |
| `BoosterSimApp/Services/DeepLinkService.swift` (modify) | service | request-response (migrate onto seam) | self — delete lines 54-87, keep parse/history | self | Keeping the `Task.detached` + direct-`Process` block (the convention exception Phase 3 deletes); porting the async/await shape into new code |
| `BoosterSimApp/Utilities/AppLogger.swift` (modify) | utility | — | self — static category registry (lines 5-14) | self | Logging defaults values/domains beyond key names (extends "never log sensitive data") |
| `BoosterSimApp/App/AppDelegate.swift` (modify) | app wiring | — | self — lazy var block (lines 17-25) | self | Constructing services outside `AppDelegate` or passing them view-to-view |
| `BoosterSimApp/Views/SideWindow/SideWindowView.swift` (modify) | component (wiring) | — | self — `.environmentObject` chain (lines 111-120) | self | Forgetting the new services in the chain → views crash on `@EnvironmentObject` |
| `BoosterSimAppTests/AppActionServiceTests.swift` | test | — | `BoosterSimAppTests/NetworkConditionServiceTests.swift` | exact | Testing live simctl instead of pure builders/sequencing |
| `BoosterSimAppTests/PushPayloadTests.swift` | test | — | `BoosterSimAppTests/BlockRuleTests.swift` + `CommandPayloadTests.swift` | exact | Only happy-path encode; missing 4096 boundary + non-object rejection |
| `BoosterSimAppTests/PrivacyPermissionTests.swift` | test | — | `BoosterSimAppTests/BlockRuleTests.swift` | exact | Asserting on labels instead of the verbatim simctl service strings |
| `BoosterSimAppTests/DerivedDataAppScannerTests.swift` | test | — | `BoosterSimAppTests/ConditionVerdictTests.swift` | role-match | Scanning the real `~/Library/Developer/Xcode/DerivedData` instead of a fixture tree |
| `BoosterSimAppTests/UserDefaultsEditorServiceTests.swift` | test | — | `BoosterSimAppTests/NetworkConditionServiceTests.swift:8-13,30-45` (isolated suite + re-init) | exact | Parsing a live device plist; using `.standard` defaults |
| `BoosterSimAppTests/AppActionCatalogTests.swift` | test | — | `BoosterSimAppTests/ConditionVerdictTests.swift` + `BlockRuleTests.swift` | exact | Skipping empty-query and no-match cases |

## Pattern Assignments

### `BoosterSimApp/Services/AppActionService.swift` (service facade, state machine)

**Analog:** `BoosterSimApp/Services/CertificateService.swift` (destructive-op state machine + the reset D-02 delegates to) + `BoosterSimApp/Services/EnvironmentOverrideService.swift` (multi-verb Combine chains)

**Init-injected deps + published state** — CertificateService.swift lines 24-37:
```swift
    private let simCtl: SimCtlService
    private let store = CertificateStore()
    private let defaults: UserDefaults

    private var cancellables = Set<AnyCancellable>()
    private var lastFailedAction: RetryAction?

    init(simCtl: SimCtlService, defaults: UserDefaults = .standard) {
        self.simCtl = simCtl
        self.defaults = defaults
        reconcileStatus(udid: nil)
    }
```
The published pair above it (lines 17-18) is `@Published private(set) var status/operation` — mirror as e.g. `@Published private(set) var operation: AppActionOperation = .idle`.

**State-machine quartet** — CertificateService.swift lines 148-170:
```swift
    private func begin(_ next: CertificateOperation) -> Bool {
        guard !operation.isWorking else { return false }
        transition(to: next)
        return true
    }

    private func finish(with newStatus: CertificateStatus) {
        status = newStatus
        lastFailedAction = nil
        transition(to: .idle)
    }

    private func fail(_ error: CertificateError) {
        let message = store.redactPaths(in: error.errorDescription ?? "Unknown certificate error.")
        AppLogger.certificates.error("\(message, privacy: .public)")
        transition(to: .error(message))
    }

    private func transition(to next: CertificateOperation) {
        if operation != next, !operation.canTransition(to: next) {
            assertionFailure("Illegal certificate transition: \(operation) -> \(next)")
        }
        operation = next
    }
```
Define `AppActionOperation` in `CertificateModels.swift` style (`idle/working/action-specific/error(String)` + `isWorking` + `canTransition(to:)`).

**Simctl verb with 30s timeout + retry bookkeeping** — CertificateService.swift lines 173-176, 91-95:
```swift
    private func runSimCtl(_ args: [String], retryAction: RetryAction, onSuccess: @escaping () -> Void) {
        simCtl.run(args)
            .timeout(.seconds(30), scheduler: DispatchQueue.main, customError: { .timeout })
            .receive(on: DispatchQueue.main)
```
```swift
    func resetKeychain(udid: String) {
        guard !udid.isEmpty, udid != "booted" else { fail(.noUDIDSelected); return }
        guard begin(.resetting) else { return }
```
Note the `udid != "booted"` refusal — copy for every destructive action (never act on the ambiguous default).

**Multi-step verb chain (locale/template)** — EnvironmentOverrideService.swift lines 269-278:
```swift
    private func setAccessibility(key: String, notification: String, enabled: Bool, udid: String) {
        simCtl.runVoid(["spawn", udid, "defaults", "write",
                        "com.apple.Accessibility", key, "-bool", enabled ? "YES" : "NO"])
            .flatMap { [weak self] _ -> AnyPublisher<Void, SimCtlError> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.simCtl.runVoid(["spawn", udid, "notifyutil", "-p", notification])
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
```
The locale flow is this exact `[weak self]` + `flatMap` chain with the second hop being `["launch", udid, bundleID, "--terminate-running-process"]` (write `AppleLanguages`/`AppleLocale`/`AppleTimeZone` → relaunch).

**Key adaptation:** `final class AppActionService: ObservableObject` `@MainActor`, init takes `simCtl: SimCtlService` (+ `certificateService` for the D-02 reconcile handoff). `clearKeychain(udid:)` should **delegate to the existing `CertificateService.resetKeychain(udid:)`** (CertificateService.swift lines 91-101 — it already runs `keychain reset`, clears the persisted-install record via `clearPersistedInstall()`, and lands the state machine correctly), then let the caller trigger `reconcileStatus(udid:)` — the same entry point SideWindowController already drives (SideWindowController.swift lines 78-80: `certificateService.reconcileStatus(udid: simulator?.udid)` inside its simulator sink). Reset = `terminate` → `listapps` presence check (uninstall exits 0 on missing apps — Pitfall 3) → `uninstall` → optional reinstall from scanner's `productPath`.

---

### `BoosterSimApp/Services/DerivedDataAppScanner.swift` (service, FS scan)

**Analog:** `BoosterSimApp/Services/XcodeDetector.swift` — the house pure-FS-scanner style (whole file, 30 lines):

**Caseless enum + candidate paths + FileManager** — XcodeDetector.swift lines 7-19:
```swift
enum XcodeDetector {

    // Common installation paths, most likely first
    private static let candidatePaths: [String] = [
        "/Applications/Xcode.app",
        "/Applications/Xcode-beta.app",
        "/Applications/Xcode-Release.app",
        "\(NSHomeDirectory())/Applications/Xcode.app"
    ]

    // MARK: - Public API

    /// Returns the path to the active Xcode .app bundle, or nil if not found.
    static func activeXcodePath() -> String? {
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
```

**Key adaptation:** Caseless `enum DerivedDataAppScanner` with static pure functions returning value types (`[DiscoveredApp]` struct: `bundleID/name/productPath/lastBuiltAt: Equatable`). Scan `\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphonesimulator/*.app` via `FileManager.default.enumerator`/`contentsOfDirectory`, order by `attributesOfItem(forPath:)[.modificationDate]`, parse `Info.plist` with `NSDictionary(contentsOf:)` → `CFBundleIdentifier`/`CFBundleName`. **The plist half has no in-repo analog** (see No Analog Found). Keep it injectable-free and headless so `DerivedDataAppScannerTests` can run it against a fixture root — parameterize the DerivedData root instead of hardcoding `NSHomeDirectory()`.

---

### `BoosterSimApp/Services/UserDefaultsEditorService.swift` (service, CRUD)

**Analog:** `BoosterSimApp/Services/EnvironmentOverrideService.swift` — the only in-repo consumer of `spawn defaults`, i.e. the exact verb family this service wraps.

**Typed spawn defaults reads** — EnvironmentOverrideService.swift lines 89-103:
```swift
        let a11yKeys: [(String, WritableKeyPath<EnvironmentOverrideService, Bool>)] = [
            ("ReduceMotionEnabled",               \.reduceMotion),
            ("BoldTextEnabled",                    \.boldText),
            ("EnhancedBackgroundContrastEnabled", \.reduceTransparency),
            ...
        ]
        for (key, path) in a11yKeys {
            simCtl.run(["spawn", udid, "defaults", "read", "com.apple.Accessibility", key])
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] output in
                    self?[keyPath: path] = output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                })
                .store(in: &cancellables)
        }
```
**Typed spawn defaults writes** — lines 269-271 (shown in AppActionService section above).

**Key adaptation:** `@MainActor final class UserDefaultsEditorService: ObservableObject` with `init(simCtl: SimCtlService)`. `loadDomain(udid:bundleID:)` reads the plist **file** at `<container>/Library/Preferences/<bundleID>.plist` via `NSDictionary(contentsOf:)` (research-verified: writes land on disk instantly; `defaults export` is silently unsupported — never build on it), maps to `[DefaultsEntry]`; `write`/`delete` build `spawn defaults write/delete` args through `simCtl.run`. Log domain + key only — never values (house redaction rule; RESEARCH Security table).

---

### `BoosterSimApp/Services/SimCtlService.swift` (modify — the seam)

**Analog:** self — whole current file is 78 lines; the two spots Phase 3 changes:

**Current run() shape: pipes created, then wait-then-read** — SimCtlService.swift lines 34-48 and 53-61:
```swift
    func run(_ args: [String]) -> AnyPublisher<String, SimCtlError> {
        print("[SimCtl] xcrun simctl \(args.joined(separator: " "))")
        return Future { promise in
            DispatchQueue.global(qos: .userInitiated).async {
                ...
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                proc.standardOutput = stdoutPipe
                proc.standardError  = stderrPipe
```
```swift
                proc.waitUntilExit()                                    // ← line 53: deadlock risk
                let stdout = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""                                                 // ← reads AFTER exit (lines 53-61)
```

**Key adaptation:** (1) Read both pipes **concurrently with** `waitUntilExit` (e.g. `readabilityHandler` or read-before-wait) before resolving the promise — `listapps` is already 33 KB and >64 KB output hangs the tab (RESEARCH Pitfall 2). (2) Add stdin: an optional `stdin: Data?` parameter (default nil keeps all existing callers source-compatible) wired via `proc.standardInput = Pipe()` for `push <udid> -` and `pbcopy`. (3) Keep the signature `AnyPublisher<String, SimCtlError>` + main-thread delivery — every existing call site (EnvironmentOverrideService, CertificateService, StatusBarService) keeps compiling untouched.

---

### `BoosterSimApp/Models/AppAction.swift` (model, pure catalog)

**Analog:** `TrafficFilter` — `BoosterSimApp/Views/SideWindow/network/NetworkEventModel.swift` lines 45-62:

```swift
struct TrafficFilter: Sendable {
    var methods: Set<HTTPMethod> = Set(HTTPMethod.allCases)
    var statusRange: StatusRange = .all
    var searchText: String = ""

    func matches(_ event: NetworkEvent) -> Bool {
        guard methods.contains(event.method) else { return false }
        if statusRange != .all, let code = event.statusCode, !statusRange.contains(code) {
            return false
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            return event.url.lowercased().contains(q)
                || event.path.lowercased().contains(q)
                || event.host.lowercased().contains(q)
        }
        return true
    }
}
```

**Key adaptation:** `struct AppAction: Identifiable, Sendable` (`id/title/keywords/section/effectLatency`) + `enum EffectLatency { case instant, relaunch, deviceWide }` + pure `static func filter(_ actions:, query:) -> [AppAction]` (lowercased contains over title + keywords + section, empty query = all). Views never filter ad hoc — NetworkTabView.swift line 19-20 shows the house wiring: `connectService.networkEvents.filter { filter.matches($0) }`.

### `BoosterSimApp/Models/PushPayload.swift` (model, Codable + validation)

**Analog:** `BoosterSimApp/Models/BoosterCommand.swift` lines 18-21, 43-46 + `BlockRule.matches` validation style (BlockRule.swift line 21):
```swift
struct BoosterCommand: Codable, Equatable {
    /// Current payload schema version. Bump on breaking change; clients ignore
    /// snapshots with unknown versions whole (no partial application).
    static let version = 1
```
```swift
struct ThrottleSpec: Codable, Equatable {
    let latencyMs: Int
    let downloadKbps: Int
    let uploadKbps: Int?
```

**Key adaptation:** `struct PushPayload: Codable, Equatable` (`aps` nested struct with `alert/badge/sound`, optional `simulatorTargetBundle` mapped to `"Simulator Target Bundle"`) + a pure `func validate() -> PushPayloadError?` (top-level object, `aps` present, encoded size ≤ 4096). Zero third-party JSON handling precedent beyond Codable — use `JSONEncoder` and measure the encoded payload.

### `BoosterSimApp/Models/PrivacyPermission.swift` (model, verbatim-string enum)

**Analog:** `SideWindowPosition` — `BoosterSimApp/Models/AppSettings.swift` lines 9-16 + `HTTPMethod` — `NetworkEventModel.swift` lines 6-13:
```swift
enum SideWindowPosition: String, CaseIterable {
    case left, right, bottom, dynamic

    var label: String {
        switch self {
        case .left: return "Left"
```
```swift
enum HTTPMethod: String, CaseIterable, Sendable {
    case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
```

**Key adaptation:** `enum PrivacyPermission: String, CaseIterable, Sendable` whose **raw values are the verbatim simctl service strings** (`"calendar"`, `"contacts-limited"`, `"contacts"`, `"location"`, `"location-always"`, `"photos-add"`, `"photos"`, `"media-library"`, `"microphone"`, `"motion"`, `"reminders"`, `"siri"`) plus computed `label` and `var simctlArgs(udid:action:)`. **No `notifications` case** — PrivacyPermissionTests locks the 12-string set (research-verified against simctl help + positive controls). `SideWindowPosition`'s raw-value discipline applies: raw values here are exec-argv contract, not presentation.

### `BoosterSimApp/Models/DefaultsEntry.swift` (model, typed wrapper)

**Analog:** `CertificateStatus` — `BoosterSimApp/Services/CertificateModels.swift` lines 1-30 (enum with associated values + computed accessors, per Phase 5 verified excerpt):
```swift
enum CertificateStatus: Equatable {
    case notGenerated
    case generated(cn: String, expiry: Date, sha256: String)
    case installed(cn: String, expiry: Date, sha256: String, deviceName: String, udid: String)
```

**Key adaptation:** `enum DefaultsEntryValue: Equatable { case string(String), int(Int), bool(Bool), array([String]), json(Data) }` + `struct DefaultsEntry: Identifiable, Equatable` (`key`, `value`, `isModified`). Computed `var simctlTypeArg: [String]` → `["-string", v]` / `["-int", …]` / `["-bool", "YES"/"NO"]` / `["-array", …]`, unit-tested as arg builders.

---

### `BoosterSimApp/Views/SideWindow/actions/ActionSearchBar.swift` (component, search UI)

**Analog:** `BoosterSimApp/Views/SideWindow/network/TrafficFilterBar.swift` — role-exact (filter bar over a pure filter struct).

**Filter-row composition (pills + search toggle)** — TrafficFilterBar.swift lines 15-47:
```swift
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ...
                    // Search toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSearch.toggle()
                            if !showSearch { searchText = ""; filter.searchText = "" }
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark.circle.fill" : "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
```
Plus the declaration shape (lines 4-9): `@Binding var filter: TrafficFilter` / `let eventCount: Int` / `var onClear: (() -> Void)?`.

**Key adaptation:** `@Binding var query: String` (or a binding into `AppActionCatalog` state) + magnifyingglass toggle clearing on collapse; row height `SideWindowMetrics.compactRowHeight`; clear-on-hide behavior preserved so a collapsed search never filters silently.

### `BoosterSimApp/Views/SideWindow/actions/AppPickerBar.swift` (component, picker)

**Analog:** `TrafficFilterBar` horizontal pill row (lines 15-62, shown above) — horizontal `ScrollView` of `Button` pills inside `SideWindowMetrics.compactRowHeight`. The generic pill-grid signature exists in `CaptureTabView.swift` lines ~43-49 (`pillsRow/pillsGrid<Value: RawRepresentable & CaseIterable & Equatable>` with `optionPill(label:isSelected:action:)`).

**Key adaptation:** Candidates = scanner results ∩ installed (via `listapps`) with a running badge (launchctl `UIKitApplication:` rows) — **explicit user selection only** (RESEARCH Pitfall 11: no frontmost verb). Default selection = most recent `lastBuiltAt`. Keep the bar one row tall; overflow scrolls horizontally like the filter pills.

### `BoosterSimApp/Views/SideWindow/actions/AppResetSectionView.swift` (component, destructive)

**Analog:** `BoosterSimApp/Views/SideWindow/CertificateSectionView.swift` — role-exact (destructive simctl action + confirm + status).

**Declaration + view state** — CertificateSectionView.swift lines 4-16 (verified this session):
```swift
struct CertificateSectionView: View {
    let udidProvider: () -> String?
    let deviceNameProvider: () -> String

    @EnvironmentObject var certService: CertificateService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true
    @State private var showResetConfirm = false
    @AppStorage("certFirstUseHintDismissed") private var hintDismissed = false

    private var activeUDID: String? { udidProvider() }
    private var isWorking: Bool { certService.operation.isWorking }
```
**Destructive confirmation wired to the service** — lines 34-37:
```swift
        .confirmationDialog("Reset Simulator Keychain?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) { if let udid = activeUDID { certService.resetKeychain(udid: udid) } }
        } message: {
```

**Key adaptation:** Same skeleton (`@State private var showResetConfirm` + `.confirmationDialog(..., role: .destructive)` calling the service). Per D-02 the message must **name the blast radius** (ALL device keychains + the Phase 5 local CA) and the destructive button chains `appActionService.clearKeychain` → CA re-reconcile. Wrap sections in `CollapsibleSection` (BlockRulesView.swift lines 30-31 shows the wrapper call: `CollapsibleSection(title: "Block Rules", icon: "shield.lefthalf.filled", isExpanded: $isExpanded) { ... }`).

### `BoosterSimApp/Views/SideWindow/actions/PushNotificationSectionView.swift` (component, editor)

**Analog:** `BoosterSimApp/Views/SideWindow/DeepLinkSectionView.swift` — role-exact (text input + preset row + result caption + parsed-detail toggle).

**Result caption pattern** — DeepLinkSectionView.swift lines ~157-170 (verified excerpt):
```swift
private extension DeepLinkService.DeepLinkResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .success(let url): return "Opened: \(url)"
        case .error(let msg): return msg
        }
    }
}
```
Body layout (lines 14-56, structurally verified): `VStack(alignment: .leading, spacing: 12)` with URL-input `HStack(spacing: 8)` → horizontal presets `ScrollView` → result block (`.padding(8)` + green/orange 0.1-opacity background + `cornerRadius(6)`) → toggle button `.font(.caption).buttonStyle(.plain).foregroundColor(.accentColor)`.

**Key adaptation:** Same vertical flow: payload `TextEditor` (JSON) + template pills (alert/badge/sound) + send button + result caption. Validate through `PushPayload.validate()` before send; body goes through `simCtl.run(["push", udid, "-"])` with stdin (requires the SimCtlService extension). **Fix, don't copy** DeepLinkSectionView's raw `12/8/6` values (conventions.md flags lines 49/83/131 as a known deviation) — use `Spacing.md/xs` + `CornerRadius.medium`.

### `BoosterSimApp/Views/SideWindow/actions/PrivacySectionView.swift` (component, pills + honest caption)

**Analog:** `BoosterSimApp/Views/SideWindow/network/NetworkConditionsSectionView.swift` — role-exact (toggle pills over an enum set + scope caption).

**Section shell** — lines 4-20:
```swift
struct NetworkConditionsSectionView: View {

    @EnvironmentObject var networkConditionService: NetworkConditionService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
...
    var body: some View {
        CollapsibleSection(title: "Network Conditions", icon: "network", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                airplaneRow
```
**Honest scope caption (PRO-01 discipline)** — lines 139-143:
```swift
    private var scopeCaption: some View {
        Text("Affects URLSession HTTP(S) traffic in apps embedding BoosterSimConnect")
            .font(.caption)
            .foregroundStyle(.secondary)
```

**Key adaptation:** One pill per `PrivacyPermission` case (grant/revoke/reset picker) → `simCtl privacy` args; caption per D-01: notification permission is managed by iOS and **not settable from simctl** — detection/guidance to Settings.app only, never a fake toggle. Reset-all gets the destructive confirm.

### `BoosterSimApp/Views/SideWindow/actions/LocaleSectionView.swift` (component, relaunch domain)

**Analog:** `BoosterSimApp/Views/SideWindow/EnvironmentOverridesView.swift` — same backing mechanism (spawn defaults) and the degraded-state/refresh pattern.

**Grouped controls + refresh hooks** — EnvironmentOverridesView.swift lines 28-73 (excerpt):
```swift
    private var controls: some View {
        VStack(spacing: 0) {
            // ACCESSIBILITY group
            subsectionHeader("Accessibility")
            toggleRow("Increase Contrast",      icon: "circle.lefthalf.filled",
                isOn: binding(\.increaseContrast,   { service.setIncreaseContrast($0, udid: effectiveUDID) }))
            ...
            Divider().padding(.horizontal, Spacing.md)

            // APPEARANCE group
            subsectionHeader("Appearance")
            toggleRow("Dark Mode", icon: "moon",
                isOn: Binding(
                    get: { service.appearance == .dark },
                    set: { service.setAppearance($0 ? .dark : .light, udid: effectiveUDID) }))
```
```swift
        .onAppear {
            if let udid { service.loadCurrentState(udid: udid) }
        }
        .onChange(of: udid) { _, newUdid in
            if let newUdid { service.loadCurrentState(udid: newUdid) }
        }
```

**Key adaptation:** Preset pills (language/region/timezone triples) + manual pickers; every write goes through the locale chain (defaults write → `launch --terminate-running-process`) and **always** renders a "takes effect on relaunch" caption (RESEARCH Pitfall 6). Reuse the `effectiveUDID`/`isDisabled` guards (lines 15-16 of the file) and the onAppear/onChange reload.

### `BoosterSimApp/Views/SideWindow/actions/LocationSectionView.swift` (component, entry + presets)

**Analog:** `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` — validated text-entry row + limit/caption discipline.

**Validated add-row** — BlockRulesView.swift lines 101-104 and captions 147-151:
```swift
    private var addRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("domain or *.domain.com", text: $newDomain)
                .textFieldStyle(.roundedBorder)
```
```swift
    private var capCaption: some View {
        Text("Rule limit reached (\(Self.maxRules)). Delete a rule to add another.")
            .font(.caption)
            .foregroundStyle(.secondary)
```

**Key adaptation:** lat/lon TextFields (numeric validation before building `["location", udid, "set", "\(lat),\(lon)"]`), city-preset pills (city → lat/lon/timezone, per research Open Question 4 recommendation), and a **Stop button paired with every start** (RESEARCH Pitfall 10 — `location start` runs until `location clear`).

### `BoosterSimApp/Views/SideWindow/actions/ClipboardSectionView.swift` (component, two buttons)

**Analog:** `NetworkConditionsSectionView` shell (lines 4-20 shown above) + the animation helper — BlockRulesView.swift lines 16-18:
```swift
    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }
```

**Key adaptation:** Two buttons ("Mac → Simulator" = `pbsync host <udid>`, "Simulator → Mac" = `pbsync <udid> host`) + a direction-status caption. Manual triggers only — no auto-sync timer (research tradeoff table; `-p` promise data makes polling fights Simulator's own sync).

### `BoosterSimApp/Views/SideWindow/actions/UserDefaultsEditorView.swift` (component, editor UI)

**Analog:** `BoosterSimApp/Views/SideWindow/network/BlockRulesView.swift` — role-exact (key/value list rows + per-row toggle/delete + add row + honest captions).

**Row with caption capsule, toggle, delete + a11y labels** — BlockRulesView.swift lines 48-84:
```swift
    private func ruleRow(_ rule: BlockRule) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(rule.domain)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let prefix = rule.pathPrefix, !prefix.isEmpty {
                Text(prefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            Spacer()

            Toggle("", isOn: enabledBinding(rule))
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel("Block requests to \(rule.domain)")

            Button {
                networkConditionService.removeRule(id: rule.id)
            } label: {
                Image(systemName: "trash")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete rule \(rule.domain)")
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: SideWindowMetrics.rowHeight)
    }
```

**Key adaptation:** `ForEach(entries)` rows (key + typed-value capsule + edit/delete), add-row with key field + type picker, search via `AppActionCatalog`-style pure filter over keys (TrafficFilterBar search field for the input). Writes/deletes only through `UserDefaultsEditorService` (never raw `UserDefaults` in views — conventions prohibition). Search-as-you-type filters the key list locally; empty state gets a `emptyCaption`-style disclosure like BlockRulesView lines 32-34.

---

### `BoosterSimApp/Views/SideWindow/tabs/ActionsTabView.swift` (modify — self analog)

**Current file, verbatim (23 lines)** — the mount point Phase 3 extends:
```swift
    var body: some View {
        ScrollView {
            EnvironmentOverridesView(udid: udid)

            CollapsibleSection(title: "Deep Link Testing", icon: "link", isExpanded: $isDeepLinkExpanded) {
                DeepLinkSectionView(deepLinkService: deepLinkService, udid: udid)
            }
        }
    }
```
Existing `@EnvironmentObject`s: `envOverrideService`, `deepLinkService` (lines 9-10). **Multi-section tab shell precedent** — CaptureTabView.swift lines 19-40:
```swift
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xxs) {
                CollapsibleSection(title: "Screenshot", icon: "camera", isExpanded: $isScreenshotExpanded) {
                    ...
                }
                RecordingSectionView(recording: captureService.recordingService)
                ExportSectionView(exporter: captureService.exporter)
                destinationSection
            }
        }
    }
```

**Key adaptation:** Keep `EnvironmentOverridesView` + deep-link section at top untouched; append the new sections below in the `VStack(spacing: Spacing.xxs)` + per-section `@State private var is…Expanded` style (CaptureTabView lines 10-12), with `AppPickerBar` + `ActionSearchBar` pinned near the top of the scroll.

---

### `BoosterSimApp/Services/DeepLinkService.swift` (modify — migrate onto seam)

**Analog:** self. The block to DELETE — DeepLinkService.swift lines 54-87:
```swift
    func openInSimulatorAsync(udid: String?) async {
        let urlString = currentURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else {
            await MainActor.run { self.lastResult = .error(message: "URL is empty") }
            return
        }

        guard let url = URL(string: urlString), url.scheme != nil else {
            await MainActor.run { self.lastResult = .error(message: "Invalid URL format") }
            return
        }

        let deviceUDID = udid ?? "booted"
        let result: DeepLinkResult = await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "openurl", deviceUDID, urlString]
```
The block to KEEP — parseURL, lines 124-146:
```swift
    func parseURL(_ urlString: String) -> ParsedURL? {
        guard let url = URL(string: urlString) else { return nil }
        return ParsedURL(
            scheme: url.scheme,
            host: url.host,
            path: url.path,
            query: url.query,
            fragment: url.fragment,
            queryItems: url.queryItems
        )
    }
```

**Key adaptation:** Replace `openInSimulator`/`openInSimulatorAsync` with `simCtl.run(["openurl", udid ?? "booted", urlString])` sinks writing `lastResult` (needs `init(simCtl: SimCtlService)` — update `AppDelegate` line 25 and `ActionsTabView`'s construction accordingly). This **removes the DeepLinkService async/await exception** from CONVENTIONS (research: Phase 3 must shrink the exception list). Keep `parseURL`, history/favorites persistence (lines 148-186 JSON+UserDefaults pattern), and `schemePresets` — DeepLinkServiceTests pins them.

---

### Wiring (modify — self analogs)

**`BoosterSimApp/Utilities/AppLogger.swift`** — add one registry line beside the existing categories (lines 8-13: `windowTracking`, `permissions`, `settings`, `certificates`, `network`, `capture`):
```swift
    static let actions = Logger(subsystem: subsystem, category: "Actions")
```

**`BoosterSimApp/App/AppDelegate.swift`** — copy the lazy-var block style (lines 17-25, verbatim):
```swift
    lazy var statusBarService    = StatusBarService(simCtl: simCtlService)
    lazy var envOverrideService  = EnvironmentOverrideService(simCtl: simCtlService)
    ...
    lazy var certificateService  = CertificateService(simCtl: simCtlService)
```
New: `lazy var appActionService = AppActionService(simCtl: simCtlService, certificateService: certificateService)` (+ scanner/defaults-editor lazily as needed), and pass it into `sideWindowController` (lines 38-49).

**`BoosterSimApp/Views/SideWindow/SideWindowView.swift`** — extend the injection chain (lines 111-120, verbatim shape):
```swift
        .environmentObject(certificateService)
        .environmentObject(networkConditionService)
        .environmentObject(connectService)
        .environmentObject(deepLinkService)
```
Every new service consumed via `@EnvironmentObject` MUST appear here or views crash on first render.

---

### Wave 0 Test Files

**`BoosterSimAppTests/AppActionServiceTests.swift`** ← `NetworkConditionServiceTests.swift` — isolated suite helper (lines 8-13) + re-init persistence test (lines 30-45):
```swift
    private func makeDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "NetworkConditionServiceTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return (defaults, suiteName)
    }
```
```swift
    @MainActor
    @Test func airplanePersistsAcrossServiceReInit() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = NetworkConditionService(defaults: defaults, commandServer: NoopCommandBroadcast())
        #expect(first.state == .idle)
        first.setAirplane(true)
```
State-machine transition tests to copy verbatim in shape — lines 15-27:
```swift
    @Test func networkConditionStateAllowsExpectedTransitions() {
        #expect(NetworkConditionState.idle.canTransition(to: .applying))
        ...
    }

    @Test func networkConditionStateRejectsReentrantApplying() {
        #expect(!NetworkConditionState.applying.canTransition(to: .applying))
```
Apply to: reset sequence builders (terminate → listapps pre-check → uninstall → optional reinstall), operation transitions.

**`BoosterSimAppTests/PushPayloadTests.swift`** ← `BlockRuleTests.swift` maker-helper style (lines 9-19) + `CommandPayloadTests` encode/decode discipline:
```swift
    private func makeRule(
        domain: String,
        pathPrefix: String? = nil,
        isEnabled: Bool = true
    ) -> BlockRule {
        BlockRule(id: UUID(), domain: domain, pathPrefix: pathPrefix, isEnabled: isEnabled)
    }
```
Apply to: aps encode round-trip, `Simulator Target Bundle` mapping, 4096-byte boundary (4095 ok / 4096 rejected), non-object payload rejection.

**`BoosterSimAppTests/PrivacyPermissionTests.swift`** ← `BlockRuleTests.swift` contract style (lines 36-42 show the negative-case discipline):
```swift
    @Test func wildcardSuffixRejectsNonDotBoundaryLookalike() {
        let rule = makeRule(domain: "*.example.com")
        // "badexample.com" ends with "example.com" but NOT ".example.com" —
        ...
        #expect(!rule.matches(makeRequest("https://badexample.com/")))
    }
```
Apply to: assert the exact 12 raw values; assert no `notifications` case exists; assert `simctlArgs` composition per action.

**`BoosterSimAppTests/DerivedDataAppScannerTests.swift`** ← `ConditionVerdictTests.swift` pure input→output style (lines 6-27):
```swift
    private func makeRequest(_ urlString: String) -> URLRequest {
        URLRequest(url: URL(string: urlString)!)
    }
    ...
        let verdict = evaluate(
            request: makeRequest("https://api.example.com/v1/users"),
            snapshot: snapshot
        )

        #expect(verdict == .fail(.notConnectedToInternet))
```
Apply to: fixture DerivedData tree committed in the test bundle → scanner(root:) injected root; assert bundle IDs, mtime ordering, `-iphonesimulator` filtering, WorkspacePath preference. **No fixture-tree precedent exists in-repo** (see No Analog Found).

**`BoosterSimAppTests/UserDefaultsEditorServiceTests.swift`** ← `NetworkConditionServiceTests.swift` (makeDefaults + re-init pattern above); fixture plist in test bundle → typed `[DefaultsEntry]`; write/delete arg builders asserted as string arrays (no live device).

**`BoosterSimAppTests/AppActionCatalogTests.swift`** ← `ConditionVerdictTests.swift` / `BlockRuleTests.swift` pure matcher contract: keyword hit, section grouping, empty query returns all, no-match returns [], case-insensitivity.

---

## Shared Patterns

### The SimCtlService seam (applies to EVERY action)
**Source:** CONVENTIONS.md "Shell Commands" + `SimCtlService.swift:34-72`
**Apply to:** AppActionService, UserDefaultsEditorService, DeepLinkService migration.
```swift
simCtl.run(["privacy", udid, "grant", permission.rawValue])   // never Process() directly
```
No new `Process`/`Task.detached` anywhere; the only direct-`Process` site in the app (DeepLinkService:67-70) is deleted this phase. All new verbs stay UDID-scoped args from the tracker's active simulator; refuse `udid == "booted"` for destructive ops (`CertificateService.swift:92`).

### `@MainActor final class` + `@Published private(set)` + init-injected deps
**Source:** `CertificateService.swift:14-37`, `EnvironmentOverrideService.swift:16-52`
**Apply to:** AppActionService, UserDefaultsEditorService. Combine-only — no `Task {}` in services (RESEARCH Pitfall 12); scanner is the exception because it is a pure caseless enum, not an ObservableObject.

### `[weak self]` + `flatMap` multi-verb chains
**Source:** `EnvironmentOverrideService.swift:269-278` (write → notify), `:160-186` (3-write chain)
**Apply to:** locale (write → relaunch), reset (terminate → listapps → uninstall → reinstall), keychain (reset → reconcile). Always `.store(in: &cancellables)`.

### CollapsibleSection composition + Reduce Motion animation
**Source:** `CollapsibleSection.swift` (whole file); animation helper `BlockRulesView.swift:16-18`; wrapper call `NetworkConditionsSectionView.swift:16-20`
**Apply to:** all 7 new section views + ActionsTabView composition.
```swift
    private var animation: Animation {
        reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.2)
    }
```

### Honest scope captions (PRO-01 discipline)
**Source:** `NetworkConditionsSectionView.swift:139-143`
**Apply to:** PrivacySectionView (D-01 caption), LocaleSectionView ("takes effect on relaunch"), ClipboardSectionView ("text clipboard"), AppResetSectionView (blast radius), keychain (device-wide + CA wipe).
```swift
        Text("Affects URLSession HTTP(S) traffic in apps embedding BoosterSimConnect")
            .font(.caption)
            .foregroundStyle(.secondary)
```

### Destructive confirm → state machine → reconcile
**Source:** `CertificateSectionView.swift:34-37` (dialog), `CertificateService.swift:91-101` (resetKeychain), `:123-144` (reconcileStatus), `SideWindowController.swift:78-80` (reconcile wiring)
**Apply to:** AppResetSectionView + AppActionService.clearKeychain (D-02: dialog names ALL keychains + local CA, then re-reconcile through the existing CertificateService path).

### Design tokens + plain buttons + a11y labels
**Source:** `BlockRulesView.swift:48-84` (row anatomy: `.buttonStyle(.plain)`, `.accessibilityLabel`, `SideWindowMetrics.rowHeight`, capsule captions), DesignTokens.md rules
**Apply to:** every new view. Do NOT copy DeepLinkSectionView's raw `12/8/6` or CaptureTabView's legacy paddings (flagged conventions deviations).

### Logging without secrets
**Source:** `CertificateService.swift:160-164` (`AppLogger.certificates.error("\(message, privacy: .public)")` + redaction)
**Apply to:** AppActionService + UserDefaultsEditorService via new `AppLogger.actions` — log domain/key/verb, never values or UDID-bearing payloads.

### Test house style
**Source:** `NetworkConditionServiceTests.swift:8-45`, `BlockRuleTests.swift:9-42`, `ConditionVerdictTests.swift:6-27`
**Apply to:** all 6 Wave 0 files — Swift Testing (`import Testing`, `@Test`, `#expect`, `try #require`), isolated `UserDefaults` suites with `defer { removePersistentDomain }`, pure-logic contracts over the app's real types, `@MainActor` only when the SUT needs it.

## No Analog Found

Files (or sub-problems) with no close existing match — planner should use RESEARCH.md guidance for these parts:

| File / Sub-problem | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `DerivedDataAppScanner.swift` — Info.plist parse + mtime ordering | service | batch | XcodeDetector covers only `fileExists` walks; no in-repo `NSDictionary(contentsOf:)`/`PropertyListSerialization` consumer or mtime-sorted scan exists. Research §5 pins the glob + `CFBundleIdentifier` extraction. |
| `DerivedDataAppScannerTests.swift` — fixture DerivedData tree | test | batch | No existing test bundles a fixture directory tree (all current tests are pure-logic or defaults-suite based). Fixture must be created in the test bundle; scanner must take an injectable root. |
| `PushPayload.swift` — JSON payload + 4096-byte gate | model | transform | Closest Codable models (`BoosterCommand`, `DeepLinkEntry`) never validate encoded size or enforce top-level shape; validation logic is new (spec lives in RESEARCH push verb table). |
| `AppPickerBar.swift` — candidate ∩ installed ∩ running reconcile | component | request-response | No existing view merges multi-source state into a selection UI; the TrafficFilterBar pill row is layout-only. Behavior (badge running, default most-recent, explicit pick) comes from RESEARCH §5 recommendation. |

## Metadata

**Analog search scope:** `BoosterSimApp/Services/`, `BoosterSimApp/Models/`, `BoosterSimApp/Views/SideWindow/**`, `BoosterSimApp/Utilities/`, `BoosterSimApp/App/`, `BoosterSimApp/Windows/`, `BoosterSimAppTests/`
**Files read for excerpts:** 20 source files (+ 2 precedent PATTERNS docs; every quoted range verified this session via read or line-anchored grep)
**Pattern extraction date:** 2026-08-31
