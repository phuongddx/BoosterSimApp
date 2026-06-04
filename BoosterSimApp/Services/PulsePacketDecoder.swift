// PulsePacketDecoder.swift — Pure static functions for Pulse binary protocol parsing
import Foundation

// MARK: - Packet Codes

enum PulsePacketCode: UInt8 {
    case clientHello = 0
    case serverHello = 1
    case ping = 6
    case storeEventMessageStored = 7
    case storeEventNetworkTaskCreated = 8
    case storeEventNetworkTaskProgressUpdated = 9
    case storeEventNetworkTaskCompleted = 10
}

// MARK: - Header Constants

enum PulseHeader {
    static let size = 5               // [code: UInt8][contentSize: UInt32 BE]
    static let manifestEntrySize = 4  // UInt32 big-endian per manifest field
}

// MARK: - Codable Pulse Types

struct PulseClientHello: Codable {
    let version: Int
    let deviceInfo: PulseDeviceInfo
    let appInfo: PulseAppInfo
}

struct PulseDeviceInfo: Codable {
    let name: String?
    let systemName: String?
    let systemVersion: String?
    let model: String?
}

struct PulseAppInfo: Codable {
    let bundleId: String?
    let name: String?
    let version: String?
    let buildNumber: String?
}

struct PulseNetworkEvent: Codable, Sendable {
    var taskId: UUID
    var taskType: Int16
    var createdAt: Date
    var originalRequest: PulseRequest
    var currentRequest: PulseRequest?
    var response: PulseResponse?
    var error: PulseResponseError?
    var metrics: PulseMetrics?
    var label: String?
}

struct PulseRequest: Codable, Sendable {
    var url: URL?
    var httpMethod: String?
    var headers: [String: String]?
}

struct PulseResponse: Codable, Sendable {
    var statusCode: Int?
    var headers: [String: String]?
}

struct PulseResponseError: Codable, Sendable {
    var code: Int
    var domain: String
    var debugDescription: String
}

struct PulseMetrics: Codable, Sendable {
    var taskInterval: DateInterval
    var redirectCount: Int
}

// MARK: - Decoder

enum PulsePacketDecoder {

    /// Parses 5-byte header: [code: UInt8][contentSize: UInt32 BE]
    static func parseHeader(_ data: Data) -> (code: UInt8, contentSize: UInt32)? {
        guard data.count >= PulseHeader.size else { return nil }
        let code = data[0]
        var raw = UInt32(0)
        withUnsafeMutableBytes(of: &raw) { $0.copyBytes(from: data[1..<5]) }
        return (code, UInt32(bigEndian: raw))
    }

    /// Decompresses zlib-compressed body data
    static func decompressBody(_ data: Data) -> Data? {
        do {
            return try NSData(data: data).decompressed(using: .zlib) as Data
        } catch {
            return nil
        }
    }

    /// Decodes a clientHello packet body (after header stripped)
    static func decodeClientHello(_ data: Data) -> PulseClientHello? {
        guard let decompressed = decompressBody(data) else { return nil }
        return try? JSONDecoder().decode(PulseClientHello.self, from: decompressed)
    }

    /// Decodes networkTaskCompleted (code 10): decompress then split manifest
    static func decodeNetworkTaskCompleted(_ data: Data)
        -> (json: PulseNetworkEvent, requestBody: Data?, responseBody: Data?)? {
        guard let decompressed = decompressBody(data) else { return nil }
        guard decompressed.count >= PulseHeader.manifestEntrySize * 3 else { return nil }

        // Read 3 UInt32 BE values: messageSize, requestBodySize, responseBodySize
        let messageSize = readUInt32BE(decompressed, offset: 0)
        let requestBodySize = readUInt32BE(decompressed, offset: 4)
        let responseBodySize = readUInt32BE(decompressed, offset: 8)

        let manifestEnd = PulseHeader.manifestEntrySize * 3
        let jsonEnd = manifestEnd + Int(messageSize)
        let reqEnd = jsonEnd + Int(requestBodySize)
        let resEnd = reqEnd + Int(responseBodySize)

        guard decompressed.count >= resEnd else { return nil }

        let jsonData = decompressed[manifestEnd..<jsonEnd]
        let requestBody = requestBodySize > 0 ? Data(decompressed[jsonEnd..<reqEnd]) : nil
        let responseBody = responseBodySize > 0 ? Data(decompressed[reqEnd..<resEnd]) : nil

        guard let event = try? JSONDecoder().decode(PulseNetworkEvent.self, from: jsonData) else { return nil }
        return (event, requestBody, responseBody)
    }

    /// Decodes networkTaskCreated (code 8): returns raw JSON data after decompression
    static func decodeNetworkTaskCreated(_ data: Data) -> Data? {
        return decompressBody(data)
    }

    /// Encodes a serverHello packet: code 1 + zlib-compressed JSON
    static func encodeServerHello() -> Data {
        let payload: [String: String] = ["version": "1.0.0"]
        guard let json = try? JSONEncoder().encode(payload) else { return Data() }
        return buildPacket(code: PulsePacketCode.serverHello.rawValue, payload: json)
    }

    /// Encodes a pong packet: code 6, empty body
    static func encodePong() -> Data {
        return buildPacket(code: PulsePacketCode.ping.rawValue, payload: nil)
    }

    // MARK: - Private Helpers

    /// Reads UInt32 big-endian from Data at offset (safe alignment via copyBytes)
    private static func readUInt32BE(_ data: Data, offset: Int) -> UInt32 {
        var raw = UInt32(0)
        withUnsafeMutableBytes(of: &raw) { $0.copyBytes(from: data[offset..<offset + 4]) }
        return UInt32(bigEndian: raw)
    }

    // MARK: - Private Helpers

    private static func buildPacket(code: UInt8, payload: Data?) -> Data {
        var packet = Data([code])
        let compressed: Data
        if let payload {
            compressed = (try? NSData(data: payload).compressed(using: .zlib) as Data) ?? Data()
        } else {
            compressed = Data()
        }
        var size = UInt32(compressed.count).bigEndian
        packet.append(Data(bytes: &size, count: 4))
        packet.append(compressed)
        return packet
    }
}
