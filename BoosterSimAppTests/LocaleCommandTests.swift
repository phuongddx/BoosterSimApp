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

    // MARK: - Location Builders (SC3 — validated coords + city presets)

    @Test func validCoordinatesBuildTheLocationSetVerb() {
        #expect(AppActionService.locationSetCommand(udid: udid, lat: "35.6762", lon: "139.6503")
                == .success(["location", udid, "set", "35.6762,139.6503"]))
    }

    /// Typed validation BEFORE any verb (T-03-13): invalid input builds NO args.
    @Test func invalidCoordinatesReturnTypedErrorsAndBuildNoArgs() {
        let cases: [(String, String, CoordinateError)] = [
            ("", "139.6503", .latitudeEmpty),
            ("35.6762", "", .longitudeEmpty),
            ("abc", "139.6503", .latitudeNotNumeric),
            ("35.6762", "139,6503", .longitudeNotNumeric),
            ("91", "139.6503", .latitudeOutOfRange),
            ("-90.5", "139.6503", .latitudeOutOfRange),
            ("35.6762", "-180.5", .longitudeOutOfRange),
            ("35.6762", "181", .longitudeOutOfRange),
        ]
        for (lat, lon, expected) in cases {
            if case .failure(let error) = AppActionService.locationSetCommand(udid: udid, lat: lat, lon: lon) {
                #expect(error == expected)
            } else {
                Issue.record("(\(lat), \(lon)) must fail validation, not build args")
            }
        }
    }

    /// Boundary values ARE valid: |lat| == 90, |lon| == 180.
    @Test func boundaryCoordinatesAreValid() {
        #expect(AppActionService.locationSetCommand(udid: udid, lat: " 90 ", lon: "-180")
                == .success(["location", udid, "set", "90,-180"]))
    }

    @Test func clearComposesTheLocationClearVerb() {
        #expect(AppActionService.locationClearCommand(udid: udid) == ["location", udid, "clear"])
    }

    @Test func cityPresetsCarryCorrectCoordinateTimezoneTriples() {
        let expected: [CityPreset: (lat: String, lon: String, timezone: String)] = [
            .sanFrancisco: ("37.7749", "-122.4194", "America/Los_Angeles"),
            .newYork: ("40.7128", "-74.0060", "America/New_York"),
            .london: ("51.5074", "-0.1278", "Europe/London"),
            .tokyo: ("35.6762", "139.6503", "Asia/Tokyo"),
            .singapore: ("1.3521", "103.8198", "Asia/Singapore"),
            .sydney: ("-33.8688", "151.2093", "Australia/Sydney"),
        ]
        #expect(CityPreset.allCases.count >= 6)
        for preset in CityPreset.allCases {
            let triple = expected[preset]
            #expect(triple != nil)
            #expect(preset.lat == triple?.lat)
            #expect(preset.lon == triple?.lon)
            #expect(preset.timezone == triple?.timezone)
        }
    }

    /// City presets set BOTH location and timezone: the chain composes the Task-1 timezone
    /// write and ends in the relaunch hop (acceptance criterion); re-apply is identical.
    @Test func cityPresetChainComposesLocationSetTimezoneWriteAndRelaunch() {
        let tokyo = CityPreset.tokyo
        let chain = AppActionService.cityPresetChain(preset: tokyo, udid: udid, bundleID: bundle)
        #expect(chain == [
            ["location", udid, "set", "35.6762,139.6503"],
            AppActionService.timezoneArgs(timezone: "Asia/Tokyo", udid: udid),
            AppActionService.relaunchArgs(udid: udid, bundleID: bundle),
        ])
        #expect(chain == AppActionService.cityPresetChain(preset: tokyo, udid: udid, bundleID: bundle))
    }

    @Test func cityPresetCoordinatesPassValidation() {
        for preset in CityPreset.allCases {
            if case .failure = AppActionService.locationSetCommand(udid: udid, lat: preset.lat, lon: preset.lon) {
                Issue.record("\(preset.name) preset coordinates must be valid")
            }
        }
    }

    // MARK: - Clipboard Builders (SC3 — pbsync both directions)

    /// The direction enum maps to exactly the two research-verified argv forms.
    @Test func clipboardDirectionsMapToTheExactPbsyncArgv() {
        #expect(AppActionService.pbsyncCommand(direction: .macToDevice, udid: udid)
                == ["pbsync", "host", udid])
        #expect(AppActionService.pbsyncCommand(direction: .deviceToMac, udid: udid)
                == ["pbsync", udid, "host"])
    }

    // MARK: - Service Fail-Fast (typed errors before any subprocess)

    @MainActor
    @Test func setLocationWithInvalidInputFailsFastWithoutSimulating() {
        let service = makeService()
        service.setLocation(lat: "abc", lon: "139.6503", udid: udid)
        #expect(service.hasSimulatedLocation == false)
        #expect(service.locationCaption != nil)   // typed inline error surfaced
    }

    @MainActor
    @Test func verbsWithoutASimulatorSurfaceTypedCaptions() {
        let service = makeService()
        service.setLocation(lat: "35.6762", lon: "139.6503", udid: "")
        #expect(service.hasSimulatedLocation == false)
        #expect(service.locationCaption?.isEmpty == false)
        service.syncClipboard(direction: .macToDevice, udid: "")
        #expect(service.clipboardCaption?.isEmpty == false)
    }

    // MARK: - Helpers

    @MainActor
    private func makeService() -> AppActionService {
        let simCtl = SimCtlService()
        return AppActionService(simCtl: simCtl, certificateService: CertificateService(simCtl: simCtl))
    }

}
