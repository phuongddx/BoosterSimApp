// DerivedDataAppScannerTests.swift — Fixture-tree contracts for the DerivedData iOS app scanner
import Foundation
import Testing
@testable import BoosterSimApp

struct DerivedDataAppScannerTests {

    private let fileManager = FileManager.default

    // MARK: - Fixture Tree

    /// Builds a throwaway DerivedData fixture tree in a temp directory — the scanner's root is
    /// always injected, never the real home DerivedData.
    private func makeFixtureRoot() throws -> URL {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("DerivedDataAppScannerTests-\(UUID().uuidString)", isDirectory: true)

        // Tree A — newest build of com.ddat.alpha
        try writeAppBundle(root: root, tree: "ProjectA-aaaaaaaa", config: "Debug-iphonesimulator",
                           app: "AlphaApp", bundleID: "com.ddat.alpha", name: "Alpha", age: 100)
        // Tree B — distinct bundle, older
        try writeAppBundle(root: root, tree: "ProjectB-bbbbbbbb", config: "Release-iphonesimulator",
                           app: "BetaApp", bundleID: "com.ddat.beta", name: "Beta", age: 200)
        // Tree C — SAME bundle ID as Tree A, older build (dedupe loser, stays visible as alternative)
        try writeAppBundle(root: root, tree: "ProjectC-cccccccc", config: "Debug-iphonesimulator",
                           app: "AlphaApp", bundleID: "com.ddat.alpha", name: "Alpha", age: 500)
        // macOS + universal product dirs must be ignored
        try writeAppBundle(root: root, tree: "ProjectD-dddddddd", config: "Debug",
                           app: "MacApp", bundleID: "com.ddat.mac", name: "Mac", age: 10)
        try writeAppBundle(root: root, tree: "ProjectD-dddddddd", config: "Debug-universal",
                           app: "UniApp", bundleID: "com.ddat.uni", name: "Uni", age: 10)
        // Corrupt Info.plist is skipped without throwing
        try writeCorruptAppBundle(root: root, tree: "ProjectE-eeeeeeee")
        // Missing CFBundleName is skipped
        try writeAppBundle(root: root, tree: "ProjectF-ffffffff", config: "Debug-iphonesimulator",
                           app: "NoName", bundleID: "com.ddat.noname", name: nil, age: 10)
        // Symlinked alias of Tree A resolves to the same tree (no duplicate candidates)
        try fileManager.createSymbolicLink(
            at: root.appendingPathComponent("AliasToA", isDirectory: true),
            withDestinationURL: root.appendingPathComponent("ProjectA-aaaaaaaa", isDirectory: true)
        )
        return root
    }

    private func writeAppBundle(root: URL, tree: String, config: String, app: String,
                                bundleID: String, name: String?, age: TimeInterval) throws {
        let appURL = root
            .appendingPathComponent("\(tree)/Build/Products/\(config)/\(app).app", isDirectory: true)
        try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        var info = ["CFBundleIdentifier": bundleID]
        if let name { info["CFBundleName"] = name }
        try (info as NSDictionary).write(to: appURL.appendingPathComponent("Info.plist"))
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -age)],
            ofItemAtPath: appURL.path
        )
    }

    private func writeCorruptAppBundle(root: URL, tree: String) throws {
        let appURL = root
            .appendingPathComponent("\(tree)/Build/Products/Debug-iphonesimulator/Corrupt.app", isDirectory: true)
        try fileManager.createDirectory(at: appURL, withIntermediateDirectories: true)
        try Data("not-a-plist".utf8).write(to: appURL.appendingPathComponent("Info.plist"))
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -10)],
            ofItemAtPath: appURL.path
        )
    }

    // MARK: - Scan Contracts

    @Test func scanReturnsBundleIDAndNameForIOSProductBuilds() throws {
        let apps = DerivedDataAppScanner.scan(root: try makeFixtureRoot())
        let ids = Set(apps.map(\.bundleID))
        #expect(ids == ["com.ddat.alpha", "com.ddat.beta"])
        #expect(apps.first(where: { $0.bundleID == "com.ddat.alpha" })?.name == "Alpha")
        #expect(apps.first(where: { $0.bundleID == "com.ddat.beta" })?.name == "Beta")
    }

    @Test func scanIgnoresMacOSAndUniversalProductDirs() throws {
        let ids = Set(DerivedDataAppScanner.scan(root: try makeFixtureRoot()).map(\.bundleID))
        #expect(!ids.contains("com.ddat.mac"))
        #expect(!ids.contains("com.ddat.uni"))
    }

    @Test func scanOrdersResultsByBuildMtimeNewestFirst() throws {
        let apps = DerivedDataAppScanner.scan(root: try makeFixtureRoot())
        #expect(apps.map(\.bundleID) == ["com.ddat.alpha", "com.ddat.beta"])
    }

    @Test func duplicateBundleIDsResolveToNewestWithVisibleAlternatives() throws {
        let alpha = DerivedDataAppScanner.scan(root: try makeFixtureRoot())
            .first(where: { $0.bundleID == "com.ddat.alpha" })
        #expect(alpha?.productPath.path
            .hasSuffix("ProjectA-aaaaaaaa/Build/Products/Debug-iphonesimulator/AlphaApp.app") == true)
        #expect(alpha?.alternativePaths.contains(where: { $0.path.contains("ProjectC-cccccccc") }) == true)
    }

    @Test func symlinkedTreeResolvesToSameTreeWithoutDuplicates() throws {
        let apps = DerivedDataAppScanner.scan(root: try makeFixtureRoot())
        #expect(apps.filter { $0.bundleID == "com.ddat.alpha" }.count == 1)
        #expect(apps.filter { $0.bundleID == "com.ddat.beta" }.count == 1)
        #expect(apps.count == 2)
    }

    @Test func corruptAndIncompletePlistEntriesAreSkipped() throws {
        let apps = DerivedDataAppScanner.scan(root: try makeFixtureRoot())
        #expect(apps.count == 2)  // neither the corrupt plist nor the name-less entry adds a candidate
    }

    @Test func emptyRootScansToNoApps() throws {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("DerivedDataAppScannerTests-empty-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        #expect(DerivedDataAppScanner.scan(root: root).isEmpty)
    }

    @Test func defaultRootPointsAtHomeDerivedData() {
        #expect(DerivedDataAppScanner.defaultRoot.path
            .hasSuffix("Library/Developer/Xcode/DerivedData"))
    }
}
