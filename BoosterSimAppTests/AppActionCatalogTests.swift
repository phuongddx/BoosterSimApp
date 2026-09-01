// AppActionCatalogTests.swift — Wave 0: pure quick-search contracts over the Actions-tab catalog
import Foundation
import Testing
@testable import BoosterSimApp

struct AppActionCatalogTests {

    // MARK: - Keyword Hits

    @Test func keywordHitReturnsTheAction() {
        // Title hit
        #expect(AppActionCatalog.filter(query: "clipboard").map(\.title)
                == AppActionCatalog.all.filter { $0.title == "Clipboard Sync" }.map(\.title))

        // Keyword hit (query matches a keyword, not the title)
        let pasteMatches = AppActionCatalog.filter(query: "paste")
        #expect(pasteMatches.contains { $0.section == .clipboard })
    }

    @Test func statusBarKeywordHitsTheNewSection() {
        // 07-05 Task 1: the Phase 6 status bar section joins the searchable catalog.
        let batteryMatches = AppActionCatalog.filter(query: "battery")
        #expect(batteryMatches.contains { $0.section == .statusBar })
    }

    @Test func cameraKeywordHitsTheCameraSection() {
        // 07-05 Task 2: Phase 6 camera/ax-tree/build-stats sections join the catalog.
        // ("camera" also matches the privacy entry's keywords — contains is the shape.)
        let cameraMatches = AppActionCatalog.filter(query: "camera")
        #expect(cameraMatches.contains { $0.section == .camera })
    }

    @Test func matchingIsCaseInsensitive() {
        let lower = AppActionCatalog.filter(query: "keychain")
        let upper = AppActionCatalog.filter(query: "KEYCHAIN")
        let mixed = AppActionCatalog.filter(query: "KeyChain")

        #expect(lower.map(\.id) == upper.map(\.id))
        #expect(lower.map(\.id) == mixed.map(\.id))
        #expect(!lower.isEmpty)
    }

    // MARK: - Empty Query & Deterministic Stable Order

    @Test func emptyQueryReturnsTheCompleteCatalogInFixedOrder() {
        #expect(AppActionCatalog.filter(query: "") == AppActionCatalog.all)
        #expect(AppActionCatalog.filter(query: "   ") == AppActionCatalog.all)   // whitespace-only is empty
    }

    @Test func sectionsNeverReorderBetweenQueries() {
        // Deterministic stable ranking: equal-relevance matches keep catalog order,
        // so the relative order of shared matches is identical for any two queries.
        let broad = AppActionCatalog.filter(query: "e")        // matches many sections
        let narrower = AppActionCatalog.filter(query: "lo")    // matches a different subset

        let broadIDs = Set(broad.map(\.id))
        let narrowerIDs = Set(narrower.map(\.id))
        let shared = broadIDs.intersection(narrowerIDs)

        let broadOrder = broad.filter { shared.contains($0.id) }.map(\.id)
        let narrowerOrder = narrower.filter { shared.contains($0.id) }.map(\.id)

        #expect(broadOrder == narrowerOrder)
        #expect(!broadOrder.isEmpty)
    }

    @Test func resultsAlwaysKeepCatalogOrder() {
        let catalogIDs = AppActionCatalog.all.map(\.id)
        for query in ["push", "location", "defaults", "a", "e"] {
            let resultIDs = AppActionCatalog.filter(query: query).map(\.id)
            let ordered = catalogIDs.filter { resultIDs.contains($0) }
            #expect(resultIDs == ordered)
        }
    }

    // MARK: - No Match

    @Test func noMatchReturnsAnEmptyResult() {
        #expect(AppActionCatalog.filter(query: "zzz-no-such-action").isEmpty)
    }

    // MARK: - Section Coverage (the catalog enumerates every section the tab renders)

    @Test func catalogCoversEveryTabSection() {
        // The Actions tab's section list, in mount order (the catalog owns the order):
        // environment (reused EnvironmentOverridesView), status bar, deep links, push,
        // privacy, locale, location, clipboard, defaults, then the Phase 6 sections
        // (camera, ax tree, build stats) before the destructive terminal reset section.
        let expectedSections: [AppActionSection] = [
            .environment, .statusBar, .deepLinks, .push, .privacy,
            .locale, .location, .clipboard, .defaults,
            .camera, .axTree, .buildStats, .reset,
        ]

        var seen: Set<AppActionSection> = []
        let firstAppearance = AppActionCatalog.all.compactMap { action -> AppActionSection? in
            guard !seen.contains(action.section) else { return nil }
            seen.insert(action.section)
            return action.section
        }

        #expect(firstAppearance == expectedSections)                 // every section, fixed order
        #expect(Set(AppActionCatalog.all.map(\.section)) == Set(expectedSections))
        #expect(expectedSections == AppActionSection.allCases)       // the tab renders the enum
    }

    // MARK: - Effect Latency (03-RESEARCH Action Latency table)

    @Test func effectLatencyMatchesTheResearchTable() {
        let latency: [String: EffectLatency] = Dictionary(
            uniqueKeysWithValues: AppActionCatalog.all.map { ($0.id, $0.effectLatency) }
        )

        // Locale and timezone take effect on the next app launch.
        for id in latency.keys where id.contains("locale") || id.contains("timezone") {
            #expect(latency[id] == .relaunch)
        }
        // Keychain reset is device-wide.
        for id in latency.keys where id.contains("keychain") {
            #expect(latency[id] == .deviceWide)
        }
        // Everything else lands instantly.
        for action in AppActionCatalog.all {
            let isRelaunchDomain = action.id.contains("locale") || action.id.contains("timezone")
            let isDeviceWide = action.id.contains("keychain")
            if !isRelaunchDomain && !isDeviceWide {
                #expect(action.effectLatency == .instant)
            }
        }
    }

    @Test func everyEntryCarriesSearchableText() {
        for action in AppActionCatalog.all {
            #expect(!action.title.isEmpty)
            #expect(!action.keywords.isEmpty)
            #expect(!action.id.isEmpty)
        }
    }
}
