# Phase 05 — Xcode Build Statistics

**Priority:** P1 | **Status:** Complete | **Effort:** 3h

**Context:** [Plan](./plan.md)

## Overview

Display recent build history with durations and a bar chart. Data source: `LogStoreManifest.plist` (plain XML plist) in each DerivedData project's `Logs/Build/` directory. No binary xcactivitylog parsing needed. FSEvents watches for new builds in real time.

## Key Insights

**LogStoreManifest.plist structure** (verified from actual file):
```xml
<key>timeStartedRecording</key><real>795798036.85</real>   <!-- CoreData epoch -->
<key>timeStoppedRecording</key><real>795798041.36</real>
<key>highLevelStatus</key><string>S</string>               <!-- S=success, else=fail -->
<key>totalNumberOfErrors</key><integer>0</integer>
<key>totalNumberOfWarnings</key><integer>0</integer>
<key>schemeIdentifier-schemeName</key><string>BoosterSimApp</string>
<key>signature</key><string>Build BoosterSimApp</string>
```

**CoreData epoch conversion:** `Date(timeIntervalSinceReferenceDate: rawTimestamp)` (2001-01-01 base)

**Duration:** `timeStoppedRecording - timeStartedRecording` (seconds, Double)

**DerivedData path:** `~/Library/Developer/Xcode/DerivedData/*/Logs/Build/LogStoreManifest.plist`
- User already granted DerivedData access in Phase 1 (security-scoped bookmark)
- Non-sandboxed app can read `~/Library/Developer/Xcode/` directly (no extra entitlements)

**FSEvents:** Use `DispatchSource.makeFileSystemObjectSource` or `NSFilePresenter` to watch DerivedData directory. Alternatively: re-use existing 0.5s Timer polling pattern to check file modification dates on `LogStoreManifest.plist` (simpler, consistent with existing architecture).

**Recommendation: Timer-based polling** (every 5s) — matches existing polling pattern, no FSEvents complexity.

## Requirements

- Parse `LogStoreManifest.plist` across all DerivedData projects
- Show last 30 builds sorted by date (newest first)
- Per-build: scheme name, date, duration (formatted "4.5s"), success/fail status
- Bar chart of last 20 build durations (SwiftUI Canvas, no Charts framework)
- Auto-refresh when new builds detected (5s poll interval)
- Show total build count + average duration in section header

## Architecture

**`BuildRecord` model** (`Models/BuildRecord.swift`):
```swift
struct BuildRecord: Identifiable, Sendable {
    let id: String               // UUID from plist key
    let schemeName: String
    let startDate: Date
    let duration: TimeInterval   // seconds
    let succeeded: Bool
    let errorCount: Int
    let warningCount: Int

    var formattedDuration: String {
        duration < 60 ? String(format: "%.1fs", duration) : String(format: "%.0fm %.0fs", duration/60, duration.truncatingRemainder(dividingBy: 60))
    }
}
```

**`BuildStatsService`** (`Services/BuildStatsService.swift`):
```swift
@MainActor final class BuildStatsService: ObservableObject {
    @Published var recentBuilds: [BuildRecord] = []
    @Published var isLoading = false

    private var pollTimer: Timer?
    private var lastScanDates: [URL: Date] = [:]  // LogStoreManifest URL → last mtime

    func startMonitoring()
    func stopMonitoring()
    private func scanDerivedData()           // finds all LogStoreManifest.plist files
    private func parseManifest(at url: URL) -> [BuildRecord]
}
```

**Polling strategy:**
```swift
private func startPollTimer() {
    pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        self?.scanDerivedData()
    }
}
```

**Scan logic:**
```swift
private func scanDerivedData() {
    let derivedDataURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/Xcode/DerivedData")
    let manifests = (try? FileManager.default.contentsOfDirectory(at: derivedDataURL, ...))
        .flatMap { projects in projects.map { $0.appendingPathComponent("Logs/Build/LogStoreManifest.plist") } }
        .filter { FileManager.default.fileExists(atPath: $0.path) }

    // Only re-parse if mtime changed
    var allRecords: [BuildRecord] = []
    for url in manifests {
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if mtime != lastScanDates[url] {
            lastScanDates[url] = mtime
            allRecords += parseManifest(at: url)
        } else {
            allRecords += cachedRecords[url] ?? []
        }
    }
    recentBuilds = allRecords.sorted { $0.startDate > $1.startDate }.prefix(30).map { $0 }
}
```

**UI** (`Views/SideWindow/BuildStatsSectionView.swift` + `BuildChartView.swift`):

```
BuildStatsSectionView
├── Section header: "Builds: 42 | Avg: 3.2s"
├── BuildChartView          — Canvas bar chart (recent 20)
└── List of BuildRecord rows (scheme, duration, date, ✓/✗)
```

**`BuildChartView`** — SwiftUI `Canvas`:
```swift
Canvas { context, size in
    let barWidth = size.width / CGFloat(records.count)
    let maxDuration = records.map(\.duration).max() ?? 1
    for (i, record) in records.enumerated() {
        let barHeight = CGFloat(record.duration / maxDuration) * size.height
        let rect = CGRect(x: CGFloat(i) * barWidth, y: size.height - barHeight,
                          width: barWidth - 2, height: barHeight)
        context.fill(Path(rect), with: .color(record.succeeded ? .orange : .red))
    }
}
.frame(height: 60)
```

## Related Code Files

| File | Action | Description |
|------|--------|-------------|
| `Models/BuildRecord.swift` | Create | Build record value type |
| `Services/BuildStatsService.swift` | Create | Polling + plist parsing (~120 LOC) |
| `Views/SideWindow/BuildStatsSectionView.swift` | Create | Build list view (~80 LOC) |
| `Views/SideWindow/BuildChartView.swift` | Create | Canvas bar chart (~50 LOC) |
| `App/AppDelegate.swift` | Modify | Own `BuildStatsService`, call `startMonitoring()` |
| `Views/SideWindow/SideWindowView.swift` | Modify | Replace "Build Stats" Coming-soon with real section |

## Implementation Steps

1. Create `Models/BuildRecord.swift` — struct with `formattedDuration` and `formattedDate` computed vars
2. Create `Services/BuildStatsService.swift`:
   - `startMonitoring()` → schedules 5s Timer, calls `scanDerivedData()` immediately
   - `stopMonitoring()` → invalidates timer
   - `scanDerivedData()` → finds manifests, checks mtime cache, parses changed ones
   - `parseManifest(at:)` → `NSDictionary(contentsOf:)` → iterate `logs` dict → map to `[BuildRecord]`
3. Create `Views/SideWindow/BuildChartView.swift` — Canvas bar chart with orange (success) / red (fail) bars
4. Create `Views/SideWindow/BuildStatsSectionView.swift`:
   - Header: build count + average duration
   - `BuildChartView(records: Array(service.recentBuilds.prefix(20)))`
   - `ForEach(service.recentBuilds)` — row: scheme name, duration badge, relative date, checkmark/x
5. Wire `BuildStatsService` into `AppDelegate`, inject into `SideWindowView`
6. Build + test: trigger a build in Xcode, verify new record appears within 5s

## Todo

- [x] Create `Models/BuildRecord.swift`
- [x] Create `Services/BuildStatsService.swift` with polling + mtime cache
- [x] Implement `parseManifest(at:)` using `NSDictionary(contentsOf:)`
- [x] Create `Views/SideWindow/BuildChartView.swift` — Canvas chart
- [x] Create `Views/SideWindow/BuildStatsSectionView.swift`
- [x] Wire into `AppDelegate` + `SideWindowView`
- [x] Build + test: trigger Xcode build, confirm stats update

## Success Criteria

- Recent builds appear within 5s of build completing
- Bar chart renders correctly with success/fail colors
- Duration formatted correctly (e.g., "4.5s", "1m 23s")
- No parsing errors on valid `LogStoreManifest.plist` files
- All 4 files under 130 LOC each

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| DerivedData path not accessible | Non-sandboxed app reads `~/Library/Developer` freely; no bookmark needed |
| Plist format version changes | Wrap `NSDictionary(contentsOf:)` in guard; skip on nil |
| Very large DerivedData (many projects) | mtime cache prevents re-parsing; limit scan to 20 most-recently-modified projects |
| `timeStoppedRecording` missing (in-progress build) | Skip records where stop time == 0 or start time only |
