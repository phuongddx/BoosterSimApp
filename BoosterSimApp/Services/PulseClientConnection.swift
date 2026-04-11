// PulseClientConnection.swift — Per-client handler for Pulse protocol connections
import Foundation
import Network

// MARK: - Decoded Event

enum PulseDecodedEvent {
    case networkTaskCompleted(event: PulseNetworkEvent, requestBody: Data?, responseBody: Data?)
    case networkTaskCreated(jsonData: Data)
}

// MARK: - Client State

enum ClientState {
    case connecting
    case waitingHello
    case active
    case disconnected
}

// MARK: - Client Connection

@MainActor
final class PulseClientConnection {

    // MARK: - Properties

    let id: UUID
    let connection: NWConnection
    private(set) var state: ClientState = .connecting
    private(set) var deviceName: String?
    private(set) var appName: String?

    var onEvent: ((PulseDecodedEvent) -> Void)?
    var onDisconnect: ((PulseClientConnection) -> Void)?
    var onStateChange: ((ClientState) -> Void)?

    private var receiveBuffer = Data()
    private static let maxBufferSize = 10 * 1024 * 1024 // 10 MB safety cap

    // MARK: - Lifecycle

    init(connection: NWConnection) {
        self.id = UUID()
        self.connection = connection
    }

    // MARK: - Public Methods

    func start() {
        updateState(.waitingHello)
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.receiveLoop()
                case .failed, .cancelled:
                    self.disconnect()
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
    }

    func disconnect() {
        guard state != .disconnected else { return }
        connection.cancel()
        receiveBuffer.removeAll()
        updateState(.disconnected)
        onDisconnect?(self)
    }

    // MARK: - Receive Loop

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, _, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.disconnect()
                    return
                }
                if let content {
                    self.receiveBuffer.append(content)
                    if self.receiveBuffer.count > Self.maxBufferSize {
                        self.disconnect()
                        return
                    }
                    self.processBuffer()
                }
                if self.state != .disconnected {
                    self.receiveLoop()
                }
            }
        }
    }

    // MARK: - Buffer Processing

    private func processBuffer() {
        while receiveBuffer.count >= PulseHeader.size {
            guard let header = PulsePacketDecoder.parseHeader(receiveBuffer) else { return }
            let totalLength = PulseHeader.size + Int(header.contentSize)

            guard receiveBuffer.count >= totalLength else { return }

            let bodyStart = PulseHeader.size
            let bodyEnd = bodyStart + Int(header.contentSize)
            let bodyData = Data(receiveBuffer[bodyStart..<bodyEnd])
            receiveBuffer.removeFirst(totalLength)

            dispatchPacket(code: header.code, body: bodyData)
        }
    }

    private func dispatchPacket(code: UInt8, body: Data) {
        switch code {
        case PulsePacketCode.clientHello.rawValue:
            handleHandshake(body)
        case PulsePacketCode.ping.rawValue:
            handlePing()
        case PulsePacketCode.storeEventNetworkTaskCompleted.rawValue:
            handleNetworkTaskCompleted(body)
        case PulsePacketCode.storeEventNetworkTaskCreated.rawValue:
            handleNetworkTaskCreated(body)
        case PulsePacketCode.storeEventNetworkTaskProgressUpdated.rawValue,
             PulsePacketCode.storeEventMessageStored.rawValue:
            // Known but unhandled — skip silently
            break
        default:
            // Unknown packet code — skip gracefully
            break
        }
    }

    // MARK: - Packet Handlers

    private func handleHandshake(_ data: Data) {
        guard let hello = PulsePacketDecoder.decodeClientHello(data) else { return }
        deviceName = hello.deviceInfo.name
        appName = hello.appInfo.name
        let helloResponse = PulsePacketDecoder.encodeServerHello()
        send(helloResponse)
        updateState(.active)
    }

    private func handlePing() {
        let pong = PulsePacketDecoder.encodePong()
        send(pong)
    }

    private func handleNetworkTaskCompleted(_ body: Data) {
        guard let result = PulsePacketDecoder.decodeNetworkTaskCompleted(body) else { return }
        onEvent?(.networkTaskCompleted(event: result.json, requestBody: result.requestBody, responseBody: result.responseBody))
    }

    private func handleNetworkTaskCreated(_ body: Data) {
        guard let jsonData = PulsePacketDecoder.decodeNetworkTaskCreated(body) else { return }
        onEvent?(.networkTaskCreated(jsonData: jsonData))
    }

    // MARK: - Send

    func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            Task { @MainActor [weak self] in
                if error != nil {
                    self?.disconnect()
                }
            }
        })
    }

    // MARK: - Private Helpers

    private func updateState(_ newState: ClientState) {
        state = newState
        onStateChange?(newState)
    }
}
