// PulseServer.swift — NWListener TCP server for Pulse protocol connections
import Foundation
import Network
import Combine

@MainActor
final class PulseServer {

    // MARK: - Properties

    private var listener: NWListener?
    private(set) var connections: [UUID: PulseClientConnection] = [:]
    private let eventSubject = PassthroughSubject<PulseDecodedEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// Publishes decoded Pulse events from all connected clients
    var eventPublisher: AnyPublisher<PulseDecodedEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Number of currently connected clients
    var connectionCount: Int {
        connections.count
    }

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }

        let params = NWParameters.tcp
        params.includePeerToPeer = true

        do {
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)
            listener.service = NWListener.Service(name: "BoosterSimApp", type: "_pulse._tcp.")

            listener.stateUpdateHandler = { (state: NWListener.State) in
                switch state {
                case .ready:
                    break
                case .failed:
                    break
                default:
                    break
                }
            }

            listener.newConnectionHandler = { [weak self] (nwConnection: NWConnection) in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(nwConnection)
                }
            }

            listener.start(queue: DispatchQueue.main)
            self.listener = listener
        } catch {
            // Failed to create listener — server remains stopped
        }
    }

    func stop() {
        for (_, connection) in connections {
            connection.disconnect()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
    }

    /// Port the listener is bound to (nil if not started or not yet ready)
    var port: UInt16? {
        guard let listener else { return nil }
        return listener.port?.rawValue
    }

    // MARK: - Connection Management

    private func handleNewConnection(_ nwConnection: NWConnection) {
        let client = PulseClientConnection(connection: nwConnection)

        // Wire event callback → forward to our subject
        client.onEvent = { [weak self] event in
            self?.eventSubject.send(event)
        }

        // Wire disconnect callback → remove from dict
        client.onDisconnect = { [weak self] disconnectedClient in
            self?.removeConnection(disconnectedClient.id)
        }

        // State change callback for future UI integration
        client.onStateChange = { [weak self] _ in
            // Placeholder for UI state propagation
        }

        connections[client.id] = client
        client.start()
    }

    func removeConnection(_ id: UUID) {
        connections.removeValue(forKey: id)
    }
}
