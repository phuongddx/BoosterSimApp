// CommandServer.swift — NWListener TCP server broadcasting condition snapshots over "_booster-cmd._tcp."
import Foundation
import Network
import OSLog

@MainActor
final class CommandServer {

    // MARK: - Properties

    private var listener: NWListener?
    private var connections: [UUID: NWConnection] = [:]
    private var latestSnapshot: BoosterCommand?

    /// Fired when a client connects before any snapshot exists, so the service
    /// layer can produce the initial reconcile push (Pattern 1).
    var onClientConnect: (() -> Void)?

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        // Loopback-only bind (threat T-05-01): Simulator apps share the host
        // network stack and reach the Mac's 127.0.0.1; nothing else on the LAN
        // can connect.
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: 0)

        do {
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: 0)!)
            listener.service = NWListener.Service(name: "BoosterSimApp", type: "_booster-cmd._tcp.")

            listener.stateUpdateHandler = { (state: NWListener.State) in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        let port = self.listener?.port?.rawValue ?? 0
                        AppLogger.network.info("Command channel ready (port \(port, privacy: .public))")
                    case .failed(let error):
                        let reason = error.localizedDescription
                        AppLogger.network.error("Command channel failed: \(reason, privacy: .public)")
                        self.stop()
                    default:
                        break
                    }
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
            AppLogger.network.error("Command channel could not start: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
    }

    // MARK: - Broadcast

    /// Encodes and frames `command`, then sends it to every connected client.
    func broadcast(_ command: BoosterCommand) {
        latestSnapshot = command
        guard let data = try? JSONEncoder().encode(command) else { return }
        let frame = CommandFrame.encode(data)
        for connection in connections.values {
            send(frame, over: connection)
        }
    }

    // MARK: - Connection Management

    private func handleNewConnection(_ nwConnection: NWConnection) {
        let id = UUID()
        connections[id] = nwConnection

        nwConnection.stateUpdateHandler = { (state: NWConnection.State) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    let count = self.connections.count
                    AppLogger.network.info("Command client connected (\(count, privacy: .public) total)")
                    if let snapshot = self.latestSnapshot {
                        // Reconcile on connect: a relaunching app immediately
                        // converges to Mac-side state.
                        if let data = try? JSONEncoder().encode(snapshot) {
                            self.send(CommandFrame.encode(data), over: nwConnection)
                        }
                    } else {
                        self.onClientConnect?()
                    }
                case .failed(let error):
                    AppLogger.network.info("Command client dropped: \(error.localizedDescription, privacy: .public)")
                    self.connections.removeValue(forKey: id)
                case .cancelled:
                    self.connections.removeValue(forKey: id)
                default:
                    break
                }
            }
        }

        nwConnection.start(queue: DispatchQueue.main)
        monitorClientInput(id: id, connection: nwConnection)
    }

    private func send(_ frame: Data, over connection: NWConnection) {
        connection.send(content: frame, completion: .contentProcessed { [weak connection] error in
            if error != nil {
                connection?.cancel()
            }
        })
    }

    /// The server never accepts client frames; the receive loop exists only to
    /// detect malformed input. Any frame violating the length-prefix contract
    /// or exceeding the 10 MB cap drops that connection — never the app.
    private func monitorClientInput(id: UUID, connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if error != nil {
                    self.connections.removeValue(forKey: id)
                    return
                }
                if let content {
                    var buffer = content
                    var malformed = false
                    while !buffer.isEmpty {
                        do {
                            _ = try CommandFrame.decodeOne(from: &buffer)
                        } catch CommandFrame.DecodeError.payloadTooLarge {
                            malformed = true
                            break
                        } catch {
                            // Incomplete trailing bytes are fine; the next
                            // receive completes them.
                            break
                        }
                    }
                    if malformed {
                        AppLogger.network.error("Command client sent malformed frame — dropping connection")
                        connection.cancel()
                        self.connections.removeValue(forKey: id)
                        return
                    }
                }
                if self.connections[id] != nil {
                    self.monitorClientInput(id: id, connection: connection)
                }
            }
        }
    }
}
