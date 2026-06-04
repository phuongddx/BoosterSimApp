// NetworkEventModel.swift — Data model for captured network traffic
import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String, CaseIterable, Sendable {
    case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS

    /// Color for method badge in traffic list
    var tintColor: String {
        switch self {
        case .GET:    return "green"
        case .POST:   return "orange"
        case .PUT:    return "blue"
        case .PATCH:  return "purple"
        case .DELETE: return "red"
        case .HEAD:   return "gray"
        case .OPTIONS: return "teal"
        }
    }
}

// MARK: - Status Range Filter

enum StatusRange: String, CaseIterable, Sendable {
    case all         = "All"
    case success     = "2xx"
    case redirect    = "3xx"
    case clientError = "4xx"
    case serverError = "5xx"

    func contains(_ code: Int) -> Bool {
        switch self {
        case .all:         return true
        case .success:     return (200...299).contains(code)
        case .redirect:    return (300...399).contains(code)
        case .clientError: return (400...499).contains(code)
        case .serverError: return (500...599).contains(code)
        }
    }
}

// MARK: - Traffic Filter

struct TrafficFilter: Sendable {
    var methods: Set<HTTPMethod> = Set(HTTPMethod.allCases)
    var statusRange: StatusRange = .all
    var searchText: String = ""

    func matches(_ event: NetworkEvent) -> Bool {
        guard methods.contains(event.method) else { return false }
        if statusRange != .all, let code = event.statusCode, !statusRange.contains(code) {
            return false
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            return event.url.lowercased().contains(q)
                || event.path.lowercased().contains(q)
                || event.host.lowercased().contains(q)
        }
        return true
    }
}

// MARK: - Network Event

struct NetworkEvent: Identifiable, Sendable {
    let id: UUID
    let method: HTTPMethod
    let url: String
    let path: String
    let host: String
    var statusCode: Int?
    var requestHeaders: [String: String]
    var responseHeaders: [String: String]?
    var requestBody: Data?
    var responseBody: Data?
    let requestDate: Date
    var responseDate: Date?
    var duration: TimeInterval?
    var error: String?

    init(
        id: UUID = UUID(),
        method: HTTPMethod,
        url: String,
        statusCode: Int? = nil,
        requestHeaders: [String: String] = [:],
        responseHeaders: [String: String]? = nil,
        requestBody: Data? = nil,
        responseBody: Data? = nil,
        requestDate: Date = Date(),
        responseDate: Date? = nil,
        duration: TimeInterval? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.method = method
        self.url = url
        self.path = Self.extractPath(from: url)
        self.host = Self.extractHost(from: url)
        self.statusCode = statusCode
        self.requestHeaders = requestHeaders
        self.responseHeaders = responseHeaders
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.requestDate = requestDate
        self.responseDate = responseDate
        self.duration = duration
        self.error = error
    }

    // MARK: - Computed Properties

    var isError: Bool {
        if let error { return true }
        if let code = statusCode { return code >= 400 }
        return false
    }

    var statusColor: String {
        if error != nil { return "red" }
        guard let code = statusCode else { return "gray" }
        switch code {
        case 200...299: return "green"
        case 300...399: return "blue"
        case 400...499: return "orange"
        default:        return "red"
        }
    }

    /// Truncated path for 260pt panel width
    var shortPath: String {
        if path.count > 40 {
            return "..." + path.suffix(37)
        }
        return path.isEmpty ? "/" : path
    }

    /// Human-readable duration
    var formattedDuration: String {
        guard let d = duration else { return "—" }
        if d < 1 {
            return String(format: "%.0fms", d * 1000)
        }
        return String(format: "%.1fs", d)
    }

    /// Pretty-printed request body (JSON-aware)
    var prettyRequestBody: String {
        bodyString(requestBody)
    }

    /// Pretty-printed response body (JSON-aware)
    var prettyResponseBody: String {
        bodyString(responseBody)
    }

    // MARK: - Private Helpers

    private func bodyString(_ data: Data?) -> String {
        guard let data else { return "—" }
        if let str = String(data: data, encoding: .utf8) {
            // Try JSON pretty-print
            if let json = try? JSONSerialization.jsonObject(with: data),
               let pretty = try? JSONSerialization.data(
                   withJSONObject: json,
                   options: [.prettyPrinted, .sortedKeys]
               ),
               let prettyStr = String(data: pretty, encoding: .utf8) {
                return prettyStr
            }
            return str
        }
        return "(\(data.count) bytes binary)"
    }

    private static func extractPath(from url: String) -> String {
        guard let comps = URLComponents(string: url) else { return url }
        return comps.path
    }

    private static func extractHost(from url: String) -> String {
        guard let comps = URLComponents(string: url) else { return url }
        return comps.host ?? url
    }
}

// MARK: - Connection State

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case searching
    case connected(String)  // device name

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .disconnected: return "Not Connected"
        case .searching:    return "Searching..."
        case .connected(let name): return "Connected to \(name)"
        }
    }
}
