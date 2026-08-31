// LocaleCommandTests.swift — Locale/timezone/global-domain simctl argv-builder contracts (SC3)
import Foundation
import Testing
@testable import BoosterSimApp

struct LocaleCommandTests {

    private let udid = "5DD825B4-FAEC-4A27-BAD4-3EC482889F0E"
    private let bundle = "com.example.app"

    // MARK: - Global Domain Constant

    /// One named constant, pinned — the token every locale/timezone write targets
    /// (research-verified `.GlobalPreferences`, the EnvironmentOverrideService precedent).
    @Test func globalDomainIsTheSingleNamedConstant() {
        #expect(AppActionService.globalDefaultsDomain == ".GlobalPreferences")
    }

    // MARK: - Write Builders

    @Test func languageWriteUsesArrayTypeOnTheGlobalDomain() {
        #expect(AppActionService.languageArgs(languages: ["en-US", "vi-VN"], udid: udid)
                == ["spawn", udid, "defaults", "write", AppActionService.globalDefaultsDomain,
                    "AppleLanguages", "-array", "en-US", "vi-VN"])
    }

    @Test func localeAndTimezoneWritesUseStringTypeWithExactKeySpellings() {
        #expect(AppActionService.localeArgs(locale: "ja_JP", udid: udid)
                == ["spawn", udid, "defaults", "write", AppActionService.globalDefaultsDomain,
                    "AppleLocale", "-string", "ja_JP"])
        #expect(AppActionService.timezoneArgs(timezone: "Asia/Tokyo", udid: udid)
                == ["spawn", udid, "defaults", "write", AppActionService.globalDefaultsDomain,
                    "AppleTimeZone", "-string", "Asia/Tokyo"])
    }

    /// Restore-to-unset (reversibility / T-03-09 mitigation) is the delete verb.
    @Test func restoreToUnsetUsesTheDeleteVerbForAllThreeKeys() {
        for key in ["AppleLanguages", "AppleLocale", "AppleTimeZone"] {
            #expect(AppActionService.deleteKeyArgs(udid: udid, key: key)
                    == ["spawn", udid, "defaults", "delete",
                        AppActionService.globalDefaultsDomain, key])
        }
    }

    // MARK: - Relaunch (Pitfall 6 — a bare write looks like a no-op)

    @Test func relaunchUsesTheOneCallTerminateRunningProcessForm() {
        #expect(AppActionService.relaunchArgs(udid: udid, bundleID: bundle)
                == ["launch", udid, bundle, "--terminate-running-process"])
    }

    /// Flagged assumption A1 fallback: terminate-then-launch two-step for the same bundle.
    @Test func fallbackRelaunchComposesTerminateThenLaunch() {
        #expect(AppActionService.fallbackRelaunchArgs(udid: udid, bundleID: bundle)
                == [["terminate", udid, bundle], ["launch", udid, bundle]])
    }

    // MARK: - Locale Presets

    @Test func localePresetsExpandDeterministicallyToLanguageLocaleTimezoneTriples() {
        let presets = LocalePreset.allCases
        #expect(presets.count >= 4)
        let ids = presets.map(\.id)
        #expect(ids.contains("en-US"))
        #expect(ids.contains("en-GB"))
        #expect(ids.contains("vi-VN"))
        #expect(ids.contains("ja-JP"))

        let japanese = presets.first { $0.id == "ja-JP" }
        #expect(japanese?.languages == ["ja-JP"])
        #expect(japanese?.locale == "ja_JP")
        #expect(japanese?.timezone == "Asia/Tokyo")

        let vietnamese = presets.first { $0.id == "vi-VN" }
        #expect(vietnamese?.languages == ["vi-VN"])
        #expect(vietnamese?.locale == "vi_VN")
        #expect(vietnamese?.timezone == "Asia/Ho_Chi_Minh")
    }

    /// Idempotent re-apply: identical presets build identical arg sequences (must-have truth 6).
    @Test func applyingTheSameLocalePresetTwiceBuildsIdenticalArgSequences() {
        let preset = LocalePreset.allCases.first { $0.id == "ja-JP" }!
        let first = AppActionService.localePresetChain(preset: preset, udid: udid, bundleID: bundle)
        let second = AppActionService.localePresetChain(preset: preset, udid: udid, bundleID: bundle)
        #expect(first == second)
        #expect(first.count == 4)                       // languages + locale + timezone + relaunch
        #expect(first.last == AppActionService.relaunchArgs(udid: udid, bundleID: bundle))
    }

    /// The preset chain writes all three keys and ends in the relaunch hop (acceptance criterion).
    @Test func localePresetChainComposesEveryWriteThenTheRelaunch() {
        let japanese = LocalePreset.allCases.first { $0.id == "ja-JP" }!
        #expect(AppActionService.localePresetChain(preset: japanese, udid: udid, bundleID: bundle)
                == [AppActionService.languageArgs(languages: japanese.languages, udid: udid),
                    AppActionService.localeArgs(locale: japanese.locale, udid: udid),
                    AppActionService.timezoneArgs(timezone: japanese.timezone!, udid: udid),
                    AppActionService.relaunchArgs(udid: udid, bundleID: bundle)])
    }

    // MARK: - Current-State Reads

    @Test func readArgsTargetTheGlobalDomainForAllThreeKeys() {
        for key in ["AppleLanguages", "AppleLocale", "AppleTimeZone"] {
            #expect(AppActionService.readKeyArgs(udid: udid, key: key)
                    == ["spawn", udid, "defaults", "read",
                        AppActionService.globalDefaultsDomain, key])
        }
    }

    /// Pure parsers over fixture `defaults read` output: array form vs trimmed scalar.
    @Test func parsersRoundTripFixtureDefaultsReadOutput() {
        let languagesOutput = """
            (
                "en-US",
                "en-VN",
                "vi-VN"
            )
            """
        #expect(AppActionService.parseLanguagesArray(from: languagesOutput)
                == ["en-US", "en-VN", "vi-VN"])
        #expect(AppActionService.parseLanguagesArray(from: "not-an-array").isEmpty)

        #expect(AppActionService.parseScalarValue(from: "  en_VN\n") == "en_VN")
        #expect(AppActionService.parseScalarValue(from: "Asia/Tokyo") == "Asia/Tokyo")
        #expect(AppActionService.parseScalarValue(from: "   \n") == nil)
    }
}
