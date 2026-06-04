# Research Report: Pulse Framework SPM Dependency

**Date:** 2026-04-11
**Scope:** SPM package structure, version, products for programmatic Xcode integration

---

## 1. Latest Stable Version

**5.1.4** — confirmed via `git ls-remote --tags` against `https://github.com/kean/Pulse.git`.

Tag history (recent):
- 5.1.4 (latest)
- 5.1.3
- 5.1.2
- 5.1.1
- 5.1.0
- 5.0.0

---

## 2. SPM Products (Library Names)

Three library products exposed:

| Product | Target | Dependencies | Purpose |
|---------|--------|-------------|---------|
| `"Pulse"` | Pulse | none | Core logging engine (LoggerStore, NetworkLogger, Logger) |
| `"PulseProxy"` | PulseProxy | Pulse | One-line auto-capture of all URLSession network traffic |
| `"PulseUI"` | PulseUI | Pulse | SwiftUI/AppKit console UI for viewing logs in-app |

**For BoosterSimApp:** You most likely need `"PulseUI"` (includes Pulse transitively) if you want the in-app console, or just `"Pulse"` if you only need programmatic logging.

---

## 3. Package.swift (verbatim from tag 5.1.4)

```swift
// swift-tools-version:5.10
import PackageDescription
let package = Package(
    name: "Pulse",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Pulse", targets: ["Pulse"]),
        .library(name: "PulseProxy", targets: ["PulseProxy"]),
        .library(name: "PulseUI", targets: ["PulseUI"])
    ],
    targets: [
        .target(name: "Pulse"),
        .target(name: "PulseProxy", dependencies: ["Pulse"]),
        .target(name: "PulseUI", dependencies: ["Pulse"]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
```

### Platform Compatibility

| Platform | Min Version | BoosterSimApp OK? |
|----------|------------|-------------------|
| macOS | 13.0 | YES (target is macOS 15+) |
| iOS | 15.0 | N/A |
| tvOS | 15.0 | N/A |
| watchOS | 9.0 | N/A |
| visionOS | 1.0 | N/A |

### Swift Tools Version

5.10 — compatible with Xcode 15.3+. BoosterSimApp requires Xcode 16.3+, so no issue.

---

## 4. SPM Dependency Snippet for Xcode Project

### In `Package.swift` (if using SPM directly):
```swift
dependencies: [
    .package(url: "https://github.com/kean/Pulse.git", from: "5.1.4")
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "PulseUI", package: "Pulse")
    ])
]
```

### For Xcode project (xcodebuild / pbxproj injection):
- **Repository URL:** `https://github.com/kean/Pulse.git`
- **Version rule:** `from: "5.1.4"` (upToNextMajor)
- **Product names to link:** `"PulseUI"` and/or `"Pulse"` and/or `"PulseProxy"`

---

## 5. Source Credibility

| Source | Type | Confidence |
|--------|------|-----------|
| `git ls-remote --tags` against github.com/kean/Pulse.git | Primary (git) | HIGH — definitive tag list |
| `raw.githubusercontent.com/.../5.1.4/Package.swift` | Primary (source) | HIGH — exact file at tagged commit |
| `raw.githubusercontent.com/.../main/Package.swift` | Primary (source) | HIGH — matches tagged version |
| GitHub releases page | Secondary | MEDIUM — release notes mention 5.0 but don't list 5.1.x explicitly in scraped content |

---

## 6. Adoption Risk Assessment

| Dimension | Assessment |
|-----------|-----------|
| Maturity | HIGH — v5.x, mature project by experienced maintainer (kean) |
| Breaking changes | Medium — 4.x → 5.0 was major; 5.1.x has been stable patch releases |
| Community | Active — ~6.3k stars, regular releases |
| Swift 6 compat | Supported since 5.0 (explicit Swift 6 concurrency work) |
| macOS console UI | **Removed in 5.0** — only iOS console in PulseUI now. Use standalone Pulse Pro macOS app instead. |
| CocoaPods | Deprecated — SPM is the primary installation method |
| License | MIT |

**Key risk for BoosterSimApp:** PulseUI's macOS console was removed in 5.0. If you need an in-app macOS log viewer, you'll need to build custom UI on top of the `Pulse` core module, or use the standalone Pulse Pro app.

---

## 7. Concrete Recommendation

**Use `"PulseUI"` product at version `"5.1.4"`.** It pulls in `Pulse` transitively and gives you the SwiftUI console view (works on macOS 13+). If you only need logging/network capture without in-app UI, use just `"Pulse"`.

For BoosterSimApp (macOS-only menu bar app), `"Pulse"` core is likely sufficient since the macOS console UI was removed. Pair with the standalone Pulse Pro app for viewing logs externally.

---

## Unresolved Questions

1. **PulseUI macOS status:** The release notes say macOS console was "removed" in 5.0, but PulseUI still compiles for macOS (.macOS(.v13)). Need to verify whether PulseUI provides any useful macOS views or if it's iOS-only now.
2. **Minimum deployment target interaction:** Pulse requires macOS 13, BoosterSimApp targets macOS 15 — no conflict, but worth confirming no runtime warnings on macOS 15.
