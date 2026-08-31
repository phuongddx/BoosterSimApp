// AppActionServiceTests.swift — Pure argv-builder, parser, reconcile, and operation contracts for app actions
import Foundation
import Testing
@testable import BoosterSimApp

struct AppActionServiceTests {

    // MARK: - Command Builders (simctl argv — 03-RESEARCH Verified Surface)

    @Test func resetCommandBuildersMatchSimctlArgv() {
        #expect(AppActionService.terminateCommand(udid: "UDID", bundleID: "com.example.app")
                == ["terminate", "UDID", "com.example.app"])
        #expect(AppActionService.listAppsCommand(udid: "UDID") == ["listapps", "UDID"])
        #expect(AppActionService.uninstallCommand(udid: "UDID", bundleID: "com.example.app")
                == ["uninstall", "UDID", "com.example.app"])
        #expect(AppActionService.installCommand(udid: "UDID", productPath: "/dd/App.app")
                == ["install", "UDID", "/dd/App.app"])
        #expect(AppActionService.launchctlCommand(udid: "UDID")
                == ["spawn", "UDID", "launchctl", "list"])
    }

    // MARK: - listapps Plist Parse

    private let listAppsXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>com.example.app</key>
        \t<dict>
        \t\t<key>CFBundleIdentifier</key>
        \t\t<string>com.example.app</string>
        \t\t<key>CFBundleName</key>
        \t\t<string>Example</string>
        \t</dict>
        \t<key>com.apple.mobilecal</key>
        \t<dict>
        \t\t<key>CFBundleIdentifier</key>
        \t\t<string>com.apple.mobilecal</string>
        \t\t<key>CFBundleName</key>
        \t\t<string>Calendar</string>
        \t</dict>
        </dict>
        </plist>
        """

    @Test func parseInstalledAppsExtractsBundleIDSet() {
        #expect(AppActionService.parseInstalledApps(fromListAppsXML: listAppsXML)
                == ["com.example.app", "com.apple.mobilecal"])
    }

    @Test func parseInstalledAppsDegradesGracefullyOnBadInput() {
        #expect(AppActionService.parseInstalledApps(fromListAppsXML: "").isEmpty)
        #expect(AppActionService.parseInstalledApps(fromListAppsXML: "not a plist").isEmpty)
    }

    // MARK: - launchctl Parse

    private let launchctlExcerpt = """
        PID Status Label
        - 0 com.apple.SpringBoard
        412 0 UIKitApplication:com.apple.mobilecal[76eb][rb-legacy]
        500 0 UIKitApplication:com.example.app[9f2a][rb-legacy]
        901 0 application.com.apple.audiovideoipc.AVAudioSessionDriver.xpc.Nc6T8k
        """

    @Test func parseRunningAppsExtractsUIKitApplicationRows() {
        #expect(AppActionService.parseRunningApps(fromLaunchctlOutput: launchctlExcerpt)
                == ["com.apple.mobilecal", "com.example.app"])
    }

    @Test func parseRunningAppsIgnoresNonAppRows() {
        #expect(AppActionService.parseRunningApps(
            fromLaunchctlOutput: "PID Status Label\n- 0 com.apple.SpringBoard\n").isEmpty)
        #expect(AppActionService.parseRunningApps(fromLaunchctlOutput: "").isEmpty)
    }

    // MARK: - Candidate Reconcile

    private func makeApp(_ bundleID: String, age: TimeInterval) -> DiscoveredApp {
        DiscoveredApp(bundleID: bundleID, name: bundleID,
                      productPath: URL(fileURLWithPath: "/dd/\(bundleID).app"),
                      lastBuiltAt: Date(timeIntervalSinceNow: -age), alternativePaths: [])
    }

    @Test func reconcileKeepsOnlyInstalledCandidatesAndBadgesRunningOnes() {
        let scanned = [makeApp("com.a", age: 10), makeApp("com.b", age: 20), makeApp("com.c", age: 30)]
        let result = AppActionService.reconcileCandidates(
            scanned: scanned,
            installed: ["com.a", "com.b", "com.other"],
            running: ["com.b", "com.uninstalled"]
        )
        #expect(result.candidates.map(\.bundleID) == ["com.a", "com.b"])
        #expect(result.runningBadges == ["com.b"])
    }

    // MARK: - Operation State Machine

    @Test func operationAllowsExpectedTransitions() {
        #expect(AppActionOperation.idle.canTransition(to: .refreshing))
        #expect(AppActionOperation.idle.canTransition(to: .resetting))
        #expect(AppActionOperation.idle.canTransition(to: .uninstalling))
        #expect(AppActionOperation.resetting.canTransition(to: .idle))
        #expect(AppActionOperation.refreshing.canTransition(to: .error("failed")))
        #expect(AppActionOperation.error("failed").canTransition(to: .idle))
        #expect(AppActionOperation.error("failed").canTransition(to: .resetting))
        #expect(AppActionOperation.idle.canTransition(to: .error("refused")))  // typed refusal path
    }

    @Test func operationRejectsReentrantWork() {
        #expect(!AppActionOperation.resetting.canTransition(to: .resetting))
        #expect(!AppActionOperation.resetting.canTransition(to: .refreshing))
        #expect(!AppActionOperation.refreshing.canTransition(to: .resetting))
        #expect(AppActionOperation.resetting.isWorking)
        #expect(AppActionOperation.refreshing.isWorking)
        #expect(!AppActionOperation.idle.isWorking)
        #expect(!AppActionOperation.error("x").isWorking)
    }

    // MARK: - Destructive UDID Refusals

    @MainActor
    @Test func resetAppRefusesAmbiguousDefaultUDIDWithoutWorking() {
        let service = makeService()
        service.resetApp(udid: "booted", bundleID: "com.example.app")
        #expect(isTypedError(service.operation))
        #expect(!service.operation.isWorking)

        service.resetApp(udid: "", bundleID: "com.example.app")
        #expect(isTypedError(service.operation))
        #expect(!service.operation.isWorking)
    }

    @MainActor
    @Test func uninstallAppRefusesAmbiguousDefaultUDID() {
        let service = makeService()
        service.uninstallApp(udid: "booted", bundleID: "com.example.app")
        #expect(isTypedError(service.operation))
        #expect(!service.operation.isWorking)
    }

    @Test func isDestructiveUDIDAcceptsOnlyConcreteUDIDs() {
        #expect(!AppActionService.isDestructiveUDID(""))
        #expect(!AppActionService.isDestructiveUDID("booted"))
        #expect(AppActionService.isDestructiveUDID("5DD825B4-1111-2222-3333-444455556666"))
    }

    // MARK: - Helpers

    @MainActor
    private func makeService() -> AppActionService {
        let simCtl = SimCtlService()
        return AppActionService(simCtl: simCtl, certificateService: CertificateService(simCtl: simCtl))
    }

    private func isTypedError(_ operation: AppActionOperation) -> Bool {
        if case .error = operation { return true }
        return false
    }
}
