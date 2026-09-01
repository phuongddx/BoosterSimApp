// AppAction.swift — Pure searchable catalog of every Actions-tab capability (fixed section order)
// TrafficFilter discipline: matching lives in ONE pure filter function; views never
// filter ad hoc (NetworkTabView wiring precedent).
import Foundation

/// When an action's effect becomes visible (03-RESEARCH Action Latency table).
enum EffectLatency: Equatable, Sendable {
    /// Lands immediately.
    case instant
    /// Takes effect on the next app launch (locale, timezone).
    case relaunch
    /// Lands immediately but affects the WHOLE device (keychain reset).
    case deviceWide

    var label: String {
        switch self {
        case .instant:     return "instant"
        case .relaunch:    return "relaunch"
        case .deviceWide:  return "device-wide"
        }
    }
}

/// The Actions tab's sections in fixed mount order — the catalog owns the tab's section order.
enum AppActionSection: String, CaseIterable, Identifiable, Sendable {
    case environment   // reused EnvironmentOverridesView (dark/Dynamic Type/a11y)
    case statusBar     // Phase 6 StatusBarSectionView (time/battery/signal presets + custom)
    case deepLinks
    case push
    case privacy
    case locale
    case location
    case clipboard
    case defaults
    case camera        // Phase 6 CameraView (Mac camera routing via AX menu automation)
    case axTree        // Phase 6 AXTreeView (manual-refresh accessibility tree inspector)
    case buildStats    // Phase 6 BuildStatsSectionView (DerivedData build history)
    case reset

    var id: String { rawValue }
}

/// One searchable action — pure data, no UI.
struct AppAction: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let keywords: [String]
    let section: AppActionSection
    let effectLatency: EffectLatency
}

/// Pure catalog + quick-search filter over it.
enum AppActionCatalog {

    /// Every Actions-tab capability in FIXED section order — the pre-existing
    /// environment + deep-link sections included (reuse entries, per CONTEXT.md).
    static let all: [AppAction] = [
        // environment (reused)
        AppAction(id: "appearance", title: "Dark / Light Appearance",
                  keywords: ["appearance", "dark mode", "light", "theme"],
                  section: .environment, effectLatency: .instant),
        AppAction(id: "dynamic-type", title: "Dynamic Type Size",
                  keywords: ["dynamic type", "content size", "text size", "font size"],
                  section: .environment, effectLatency: .instant),
        AppAction(id: "increase-contrast", title: "Increase Contrast",
                  keywords: ["contrast", "transparency"],
                  section: .environment, effectLatency: .instant),
        AppAction(id: "accessibility", title: "Accessibility Overrides",
                  keywords: ["reduce motion", "bold text", "invert", "grayscale",
                             "button shapes", "labels", "a11y"],
                  section: .environment, effectLatency: .instant),
        // status bar (Phase 6 view wired in 07-05)
        AppAction(id: "status-bar", title: "Status Bar Override",
                  keywords: ["statusbar", "status bar", "time", "battery", "signal", "preset", "custom"],
                  section: .statusBar, effectLatency: .instant),
        // deep links
        AppAction(id: "deep-links", title: "Deep Link Testing",
                  keywords: ["deep link", "url", "scheme", "openurl", "universal link", "link"],
                  section: .deepLinks, effectLatency: .instant),
        // push
        AppAction(id: "push", title: "Push Notifications",
                  keywords: ["push", "apns", "notification", "payload", "alert", "badge", "banner"],
                  section: .push, effectLatency: .instant),
        // privacy
        AppAction(id: "privacy", title: "Privacy Permissions",
                  keywords: ["privacy", "tcc", "permission", "grant", "revoke",
                             "camera", "microphone", "photos", "contacts"],
                  section: .privacy, effectLatency: .instant),
        // locale (relaunch domain)
        AppAction(id: "locale-language", title: "Language & Locale",
                  keywords: ["locale", "language", "region", "applelanguages"],
                  section: .locale, effectLatency: .relaunch),
        AppAction(id: "timezone", title: "Timezone",
                  keywords: ["timezone", "time zone", "appletimezone"],
                  section: .locale, effectLatency: .relaunch),
        // location
        AppAction(id: "location", title: "Location Simulation",
                  keywords: ["location", "gps", "coordinates", "city", "maps", "simulate"],
                  section: .location, effectLatency: .instant),
        // clipboard
        AppAction(id: "clipboard", title: "Clipboard Sync",
                  keywords: ["clipboard", "pasteboard", "pbsync", "copy", "paste"],
                  section: .clipboard, effectLatency: .instant),
        // defaults
        AppAction(id: "defaults-editor", title: "UserDefaults Editor",
                  keywords: ["defaults", "userdefaults", "preferences", "plist", "keys"],
                  section: .defaults, effectLatency: .instant),
        // camera / ax tree / build stats (Phase 6 views wired in 07-05)
        AppAction(id: "camera-routing", title: "Camera Routing",
                  keywords: ["camera", "mac camera", "front", "back", "video input"],
                  section: .camera, effectLatency: .instant),
        AppAction(id: "ax-tree", title: "AX Tree Inspector",
                  keywords: ["accessibility", "ax", "tree", "inspector", "elements", "highlight"],
                  section: .axTree, effectLatency: .instant),
        AppAction(id: "build-stats", title: "Build Statistics",
                  keywords: ["build", "stats", "xcode", "deriveddata", "chart", "times"],
                  section: .buildStats, effectLatency: .instant),
        // reset
        AppAction(id: "reset-app", title: "Reset App Data",
                  keywords: ["reset", "uninstall", "reinstall", "clear data", "fresh install"],
                  section: .reset, effectLatency: .instant),
        AppAction(id: "clear-keychain", title: "Clear Keychain",
                  keywords: ["keychain", "wipe", "trust", "certificates"],
                  section: .reset, effectLatency: .deviceWide),
    ]

    /// Lowercased contains over title + keywords + section. An empty (or whitespace-only)
    /// query returns everything. Results ALWAYS keep catalog order — a stable ranking, so
    /// equal-relevance matches never shuffle between queries.
    static func filter(_ actions: [AppAction] = all, query: String) -> [AppAction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return actions }
        let needle = trimmed.lowercased()
        return actions.filter { action in
            action.title.lowercased().contains(needle)
                || action.keywords.contains { $0.lowercased().contains(needle) }
                || action.section.rawValue.lowercased().contains(needle)
        }
    }
}
