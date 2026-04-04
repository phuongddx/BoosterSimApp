# Phase 1: Shared AppLogger Utility

## Status: complete

## Overview

Create `Utilities/AppLogger.swift` — a thin wrapper around `os.Logger` with per-category instances. All files import this instead of calling `Logger(...)` inline.

## Implementation

**File:** `BoosterSimApp/Utilities/AppLogger.swift`

```swift
import OSLog

// MARK: - AppLogger
// Centralized os.Logger instances. Use category matching the subsystem concern.
// All logs visible in Console.app — filter by subsystem "com.nextlabs.BoosterSimApp"

enum AppLogger {
    private static let subsystem = "com.nextlabs.BoosterSimApp"

    static let windowTracking = Logger(subsystem: subsystem, category: "WindowTracking")
    static let permissions     = Logger(subsystem: subsystem, category: "Permissions")
    static let settings        = Logger(subsystem: subsystem, category: "Settings")
}
```

## Steps

- [ ] Create `BoosterSimApp/Utilities/AppLogger.swift` with the enum above
- [ ] Replace `print("[WindowObserver] ...")` in `WindowObserver.swift` with `AppLogger.windowTracking.error(...)`
- [ ] Replace `print("[AppSettings] ...")` in `AppSettings.swift` with `AppLogger.settings.error(...)`

## Notes

- `subsystem` = reverse-DNS bundle ID (matches `PRODUCT_BUNDLE_IDENTIFIER` in project)
- Categories map to logical concerns, not files — keep the list short
- Log levels: `.debug` (high-freq / dev-only), `.info` (notable events), `.error` (failures)
