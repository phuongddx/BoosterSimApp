// BoosterSimConnect.swift — iOS framework entry point for network capture
// Loaded into Simulator app via Bundle.load() / dlopen in DEBUG builds.
// Activates PulseProxy swizzling to capture all URLSession traffic.
#if DEBUG && targetEnvironment(simulator)

import Foundation

#if canImport(Pulse)
import Pulse
#endif

#if canImport(PulseProxy)
import PulseProxy
#endif

@MainActor @objc public final class BoosterSimConnect: NSObject {

    // MARK: - Singleton

    @objc public static let shared = BoosterSimConnect()

    // MARK: - Activation

    private var didActivate = false

    override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard !didActivate else { return }
        didActivate = true

        #if canImport(PulseProxy)
        // Configure sensitive header/query redaction before enabling
        configureNetworkLogger()

        // Activate URLSession swizzling — captures all URLSession traffic
        URLSessionProxyDelegate.enableAutomaticRegistration()

        // Enforce Mac-pushed network conditions (airplane/block) on URLSession
        // traffic — chained exchange composes with the swizzle above
        BoosterNetworkProtocol.enableAutomaticRegistration()

        // Discover the BoosterSimApp command channel and apply condition snapshots
        BoosterCommandClient.shared.start()

        // Start remote broadcasting so BoosterSimApp can discover via Bonjour
        RemoteLogger.shared.initialize(store: .shared)
        RemoteLogger.shared.enable()
        #endif
    }

    // MARK: - Configuration

    #if canImport(Pulse)
    private func configureNetworkLogger() {
        NetworkLogger.shared = NetworkLogger {
            $0.sensitiveHeaders = [
                "Authorization", "Cookie", "Set-Cookie",
                "Access-Token", "Refresh-Token", "X-API-Key"
            ]
            $0.sensitiveQueryItems = [
                "password", "token", "secret", "api_key", "access_token"
            ]
        }
    }
    #endif
}

#endif
