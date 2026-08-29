// BoosterNetworkProtocol.swift — URLProtocol enforcing network conditions on URLSession traffic
// Pattern from Pulse's MockingURLProtocol (MIT © 2020-2026 Alexander Grebenyuk).
// Loaded into Simulator app via Bundle.load() in DEBUG builds.
#if DEBUG && targetEnvironment(simulator)

import Foundation
import ObjectiveC

/// Fails URLSession requests per the current condition snapshot (airplane →
/// NSURLErrorNotConnectedToInternet, matching block rule →
/// NSURLErrorCannotConnectToHost); forwards everything else. Installed via a
/// URLSession init method exchange that chains with Pulse's exchange — our
/// body calls the renamed selector, so both protocol prepends apply.
public final class BoosterNetworkProtocol: URLProtocol {

    // MARK: - Registration

    private static let installExchange: Void = {
        guard
            let original = class_getClassMethod(
                URLSession.self,
                #selector(URLSession.init(configuration:delegate:delegateQueue:))
            ),
            let exchanged = class_getClassMethod(
                URLSession.self,
                #selector(URLSession.booster_init2(configuration:delegate:delegateQueue:))
            )
        else { return }
        method_exchangeImplementations(original, exchanged)
    }()

    /// Exchanges `URLSession.init(configuration:delegate:delegateQueue:)`
    /// with `booster_init2` so every new session gets this protocol prepended.
    @MainActor
    public static func enableAutomaticRegistration() {
        _ = installExchange
    }

    /// Safety guard (Pulse analog): skip delegates known to break when extra
    /// protocols are injected.
    static func isConfiguringSessionSafe(delegate: URLSessionDelegate?) -> Bool {
        guard let delegate else { return true }
        let name = String(describing: type(of: delegate))
        return !name.contains("GTMSessionFetcher")
    }

    // MARK: - URLProtocol

    /// True only for requests a condition would actually change — zero
    /// overhead while all conditions are off. Guard-marked requests are never
    /// intercepted (anti-recursion, Pitfall 2).
    public override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: BoosterInternalGuard.markerKey, in: request) == nil else {
            return false
        }
        return NetworkConditionController.shared.evaluate(request: request) != .passThrough
    }
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        Self.markedInternal(request)
    }

    /// Returns `request` carrying the internal guard property. Round-trips
    /// through NSMutableURLRequest because `setProperty(_:forKey:in:)` only
    /// accepts the mutable class type.
    private static func markedInternal(_ request: URLRequest) -> URLRequest {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.setProperty(true, forKey: BoosterInternalGuard.markerKey, in: mutable)
        return (mutable.copy() as? URLRequest) ?? request
    }

    public override func startLoading() {
        // Re-evaluate: the snapshot may have changed since canInit.
        switch NetworkConditionController.shared.evaluate(request: request) {
        case .fail(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .passThrough:
            forward(request)
        }
    }

    public override func stopLoading() {
        innerTask?.cancel()
        innerTask = nil
        innerSession?.invalidateAndCancel()
        innerSession = nil
    }

    // MARK: - Pass-Through

    private var innerSession: URLSession?
    private var innerTask: URLSessionDataTask?

    /// Forwards via an inner ephemeral session. Double defense (Pitfall 2):
    /// the inner request carries the guard property AND the literal header,
    /// and the inner configuration has no protocols of its own. The swizzled
    /// init may still prepend protocols — the guard marker is the real gate.
    private func forward(_ request: URLRequest) {
        var inner = Self.markedInternal(request)
        inner.setValue("1", forHTTPHeaderField: BoosterInternalGuard.markerKey)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = []
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        innerSession = session

        let task = session.dataTask(with: inner) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data, !data.isEmpty {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        innerTask = task
        task.resume()
    }
}

// MARK: - Session Init Exchange

private extension URLSession {

    @objc class func booster_init2(
        configuration: URLSessionConfiguration,
        delegate: URLSessionDelegate?,
        delegateQueue: OperationQueue?
    ) -> URLSession {
        guard BoosterNetworkProtocol.isConfiguringSessionSafe(delegate: delegate) else {
            return self.booster_init2(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
        }
        configuration.protocolClasses = [BoosterNetworkProtocol.self] + (configuration.protocolClasses ?? [])
        return self.booster_init2(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }
}

#endif
