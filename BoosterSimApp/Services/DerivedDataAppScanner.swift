// DerivedDataAppScanner.swift — Pure DerivedData iOS .app scanner (active-app candidates for app actions)
import Foundation

/// A candidate app discovered from a DerivedData build product.
struct DiscoveredApp: Equatable, Identifiable {
    let bundleID: String
    let name: String
    let productPath: URL
    let lastBuiltAt: Date
    /// Older builds of the same bundle ID that lost the dedupe race — stay visible as alternatives.
    let alternativePaths: [URL]

    var id: String { bundleID }
}

enum DerivedDataAppScanner {

    /// Home DerivedData root — the ONLY place the home path appears; tests always inject a fixture root.
    static var defaultRoot: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")
    }

    // MARK: - Public API

    /// Scans `<root>/<tree>/Build/Products/*-iphonesimulator/*.app`: reads each .app Info.plist for
    /// CFBundleIdentifier/CFBundleName (skipping entries missing either or with a corrupt plist),
    /// resolves symlinks BEFORE dedupe (alias trees collapse), keeps the newest build per bundle ID
    /// (alternatives retained on the winner), and sorts newest-first. Pure FS work — no simctl.
    static func scan(root: URL) -> [DiscoveredApp] {
        let fileManager = FileManager.default
        guard let trees = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        var found: [DiscoveredApp] = []
        for tree in trees {
            let products = tree.appendingPathComponent("Build/Products", isDirectory: true)
            guard let platforms = try? fileManager.contentsOfDirectory(
                at: products, includingPropertiesForKeys: nil)
            else {
                continue
            }
            for platform in platforms where isSimulatorPlatform(platform.lastPathComponent) {
                guard let apps = try? fileManager.contentsOfDirectory(
                    at: platform, includingPropertiesForKeys: nil)
                else {
                    continue
                }
                for app in apps where app.pathExtension == "app" {
                    if let discovered = parse(appURL: app, fileManager: fileManager) {
                        found.append(discovered)
                    }
                }
            }
        }
        return dedupe(found)
    }

    // MARK: - Private

    /// Matches `-iphonesimulator` product dirs (Debug-iphonesimulator, Release-iphonesimulator, …)
    /// and excludes macOS/universal/iphoneos dirs.
    private static func isSimulatorPlatform(_ name: String) -> Bool {
        name == "iphonesimulator" || name.hasSuffix("-iphonesimulator")
    }

    private static func parse(appURL: URL, fileManager: FileManager) -> DiscoveredApp? {
        // Resolve symlinks BEFORE dedupe so alias trees point at the same build, not a duplicate.
        let resolved = appURL.resolvingSymlinksInPath()
        guard let info = NSDictionary(contentsOf: resolved.appendingPathComponent("Info.plist")),
              let bundleID = info["CFBundleIdentifier"] as? String, !bundleID.isEmpty,
              let name = info["CFBundleName"] as? String, !name.isEmpty
        else { return nil }
        let mtime = (try? fileManager.attributesOfItem(atPath: resolved.path))?[.modificationDate] as? Date
        return DiscoveredApp(bundleID: bundleID, name: name, productPath: resolved,
                             lastBuiltAt: mtime ?? .distantPast, alternativePaths: [])
    }

    private static func dedupe(_ apps: [DiscoveredApp]) -> [DiscoveredApp] {
        var byBundle: [String: [DiscoveredApp]] = [:]
        for app in apps {
            byBundle[app.bundleID, default: []].append(app)
        }
        return byBundle.values.map { builds -> DiscoveredApp in
            // Newest-first; identical resolved paths (symlink aliases) collapse to one entry.
            var winners: [DiscoveredApp] = []
            for build in builds.sorted(by: { $0.lastBuiltAt > $1.lastBuiltAt })
            where !winners.contains(where: { $0.productPath == build.productPath }) {
                winners.append(build)
            }
            guard let newest = winners.first else {
                return builds[0]
            }
            return DiscoveredApp(bundleID: newest.bundleID, name: newest.name,
                                 productPath: newest.productPath, lastBuiltAt: newest.lastBuiltAt,
                                 alternativePaths: winners.dropFirst().map(\.productPath))
        }
        .sorted(by: { $0.lastBuiltAt > $1.lastBuiltAt })
    }
}
