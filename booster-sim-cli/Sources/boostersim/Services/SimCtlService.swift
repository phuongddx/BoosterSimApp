// SimCtlService.swift — Wrapper for xcrun simctl commands
import Foundation

struct SimCtlService {

    static func listDevices() throws -> [SimDevice] {
        let output = try run("simctl", "list", "devices", "json")
        guard let data = output.data(using: .utf8) else {
            throw CLIError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(DeviceListResponse.self, from: data)
        return response.devices.flatMap { $0.value }
    }

    static func tap(udid: String, x: Int, y: Int) throws {
        _ = try run("simctl", "io", udid, "tap", "\(x)", "\(y)")
    }

    static func swipe(udid: String, fromX: Int, fromY: Int, toX: Int, toY: Int) throws {
        _ = try run("simctl", "io", udid, "swipe", "\(fromX)", "\(fromY)", "\(toX)", "\(toY)")
    }

    static func type(udid: String, text: String) throws {
        _ = try run("simctl", "io", udid, "type", text)
    }

    static func screenshot(udid: String, output: String) throws {
        _ = try run("simctl", "io", udid, "screenshot", output)
    }

    static func openURL(udid: String, url: String) throws {
        _ = try run("simctl", "openurl", udid, url)
    }

    // MARK: - Private

    private static func run(_ arguments: String...) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CLIError.commandFailed(output)
        }

        return output
    }
}

// MARK: - Models

struct SimDevice: Codable {
    let udid: String
    let name: String
    let state: String
    let deviceTypeIdentifier: String?
    let runtime: String?

    enum CodingKeys: String, CodingKey {
        case udid
        case name
        case state
        case deviceTypeIdentifier
        case runtime
    }
}

private struct DeviceListResponse: Codable {
    let devices: [String: [SimDevice]]
}

// MARK: - Errors

enum CLIError: Error, LocalizedError {
    case invalidOutput
    case commandFailed(String)
    case deviceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidOutput:
            return "Invalid output from simctl"
        case .commandFailed(let output):
            return "Command failed: \(output)"
        case .deviceNotFound(let name):
            return "Device not found: \(name)"
        }
    }
}
