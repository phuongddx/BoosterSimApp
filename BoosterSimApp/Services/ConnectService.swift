// ConnectService.swift — Hosts Pulse TCP server to receive network events from Simulator apps
import Foundation
import Combine
import Network

@MainActor
final class ConnectService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var networkEvents: [NetworkEvent] = []

    // MARK: - Constants

    private static let maxEvents = 500

    // MARK: - Private

    private var pulseServer: PulseServer?
    private var cancellables = Set<AnyCancellable>()
    private var hasReceivedFirstEvent = false

    // MARK: - Server Lifecycle

    func startServer() {
        guard pulseServer == nil else { return }
        hasReceivedFirstEvent = false
        connectionState = .searching

        let server = PulseServer()
        server.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleDecodedEvent(event)
            }
            .store(in: &cancellables)

        server.start()
        pulseServer = server
    }

    func stopServer() {
        pulseServer?.stop()
        pulseServer = nil
        cancellables.removeAll()
        hasReceivedFirstEvent = false
        connectionState = .disconnected
    }

    // MARK: - Public

    func clearEvents() {
        networkEvents.removeAll()
    }

    // MARK: - Event Handling

    private func handleDecodedEvent(_ decoded: PulseDecodedEvent) {
        guard let event = convertToNetworkEvent(decoded) else { return }

        // Transition from searching → connected on first event with device info
        if !hasReceivedFirstEvent {
            hasReceivedFirstEvent = true
            // Find any active client for device name
            if let client = pulseServer?.connections.values.first(where: { $0.deviceName != nil }),
               let name = client.deviceName {
                connectionState = .connected(name)
            } else {
                connectionState = .connected("Simulator")
            }
        }

        appendEvent(event)
    }

    private func convertToNetworkEvent(_ decoded: PulseDecodedEvent) -> NetworkEvent? {
        switch decoded {
        case .networkTaskCompleted(let pulseEvent, let requestBody, let responseBody):
            let url = pulseEvent.originalRequest.url?.absoluteString ?? ""
            let methodStr = pulseEvent.originalRequest.httpMethod ?? "GET"
            let method = HTTPMethod(rawValue: methodStr) ?? .GET
            let duration = pulseEvent.metrics?.taskInterval.duration
            let errorStr: String?
            if let err = pulseEvent.error {
                errorStr = "\(err.domain): \(err.debugDescription) (code \(err.code))"
            } else {
                errorStr = nil
            }

            return NetworkEvent(
                method: method,
                url: url,
                statusCode: pulseEvent.response?.statusCode,
                requestHeaders: pulseEvent.originalRequest.headers ?? [:],
                responseHeaders: pulseEvent.response?.headers,
                requestBody: requestBody,
                responseBody: responseBody,
                requestDate: pulseEvent.createdAt,
                duration: duration,
                error: errorStr
            )

        case .networkTaskCreated:
            // TaskCreated is informational only — no NetworkEvent mapping needed
            return nil
        }
    }

    // MARK: - Event Management

    private func appendEvent(_ event: NetworkEvent) {
        networkEvents.append(event)
        if networkEvents.count > Self.maxEvents {
            networkEvents.removeFirst(networkEvents.count - Self.maxEvents)
        }
    }
}
