// BoosterCommandClient.swift — framework-side client for the Mac command channel ("_booster-cmd._tcp.")
// Browses via Bonjour, connects, reassembles length-prefixed JSON frames, and
// applies full-state snapshots to NetworkConditionController.
// Loaded into Simulator app via Bundle.load() in DEBUG builds.
#if DEBUG && targetEnvironment(simulator)

import Foundation
import Network

/// NOT @MainActor — all state is confined to a private serial queue, which is
/// also the callback queue for the browser and connection (Pitfall 6). Frames
/// are idempotent full-state snapshots; a dropped connection self-heals by
/// re-browsing, and every new connection receives the complete snapshot from
/// the server (reconcile on connect).
final class BoosterCommandClient {

    static let shared = BoosterCommandClient()

    private let queue = DispatchQueue(label: "sim-dev.BoosterSimConnect.command-client")
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var isStarted = false

    private var receiveBuffer = Data()
    private static let maxBufferSize = 10 * 1024 * 1024 // 10 MB safety cap

    private init() {}

    // MARK: - Lifecycle

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isStarted else { return }
            self.isStarted = true
            self.startBrowsing()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isStarted = false
            self.browser?.cancel()
            self.browser = nil
            self.connection?.cancel()
            self.connection = nil
            self.receiveBuffer.removeAll()
        }
    }

    // MARK: - Discovery
    // Handlers run on `queue` (passed to browser.start), so they may touch
    // confined state directly.

    private func startBrowsing() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_booster-cmd._tcp.", domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { [weak self] (state: NWBrowser.State) in
            guard let self else { return }
            if case .failed = state {
                // Restart browsing so a transient mDNS hiccup self-heals.
                self.restartBrowsing()
            }
        }

        browser.browseResultsChangedHandler = { [weak self] (results: Set<NWBrowser.Result>, _) in
            guard let self else { return }
            guard self.connection == nil, let result = results.first else { return }
            self.connect(to: result.endpoint)
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    private func restartBrowsing() {
        browser?.cancel()
        browser = nil
        guard isStarted else { return }
        startBrowsing()
    }

    // MARK: - Connection

    private func connect(to endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] (state: NWConnection.State) in
            guard let self else { return }
            switch state {
            case .ready:
                self.receiveBuffer.removeAll()
                self.receiveLoop()
            case .failed, .cancelled:
                // Reconnection: drop the dead connection and browse again;
                // the server pushes the full snapshot on reconnect.
                self.connection?.cancel()
                self.connection = nil
                self.restartBrowsing()
            default:
                break
            }
        }

        self.connection = connection
        connection.start(queue: queue)
    }

    // MARK: - Receive Loop

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, _, error in
            guard let self else { return }
            if error != nil {
                self.connection?.cancel()
                return
            }
            if let content {
                self.receiveBuffer.append(content)
                if self.receiveBuffer.count > Self.maxBufferSize {
                    self.connection?.cancel()
                    return
                }
                self.processBuffer()
            }
            if self.connection != nil {
                self.receiveLoop()
            }
        }
    }

    private func processBuffer() {
        while !receiveBuffer.isEmpty {
            let payload: Data
            do {
                payload = try Self.decodeFrame(from: &receiveBuffer)
            } catch {
                // Malformed frame: drop the connection; reconcile heals on reconnect.
                connection?.cancel()
                return
            }
            apply(payload)
        }
    }

    // MARK: - Frame Decode
    // Schema-synced mirror of the Mac-side CommandFrame codec.

    private static let prefixLength = 4
    private static let maxPayloadSize = 10 * 1024 * 1024

    private enum FrameError: Error {
        case incomplete
        case payloadTooLarge
    }

    private static func decodeFrame(from buffer: inout Data) throws -> Data {
        guard buffer.count >= prefixLength else { throw FrameError.incomplete }
        // Copy into a re-based index space: a Data produced by removeFirst can
        // keep a non-zero startIndex, and raw offsets then trap (Data-slice
        // alignment trap — connect-transport-rewrite precedent).
        let bytes = [UInt8](buffer)
        var length = UInt32(0)
        for byte in bytes[0..<prefixLength] {
            length = (length << 8) | UInt32(byte)
        }
        guard Int(length) <= maxPayloadSize else { throw FrameError.payloadTooLarge }
        let totalLength = prefixLength + Int(length)
        guard bytes.count >= totalLength else { throw FrameError.incomplete }
        let payload = Data(bytes[prefixLength..<totalLength])
        buffer = Data(bytes[totalLength...])
        return payload
    }

    // MARK: - Apply

    private func apply(_ payload: Data) {
        guard let command = try? JSONDecoder().decode(BoosterCommand.self, from: payload) else {
            return
        }
        NetworkConditionController.shared.update(command)
    }
}

#endif
