// CurlExporter.swift — Convert NetworkEvent to cURL command string
import AppKit

enum CurlExporter {

    /// Generate a cURL command from a network event.
    /// Redacts sensitive headers (Authorization, Cookie).
    static func export(_ event: NetworkEvent) -> String {
        var parts = ["curl"]

        // Method (skip GET — it's the default)
        if event.method != .GET {
            parts.append("-X \(event.method.rawValue)")
        }

        // URL (single-quoted)
        parts.append("'\(event.url)'")

        // Request headers
        let sensitiveHeaders: Set<String> = [
            "authorization", "cookie", "set-cookie",
            "access-token", "refresh-token", "x-api-key"
        ]
        for (key, value) in event.requestHeaders.sorted(by: { $0.key.lowercased() < $1.key.lowercased() }) {
            if sensitiveHeaders.contains(key.lowercased()) {
                parts.append("-H '\(key): [REDACTED]'")
            } else {
                parts.append("-H '\(key): \(value)'")
            }
        }

        // Request body
        if let body = event.requestBody,
           let bodyStr = String(data: body, encoding: .utf8) {
            // Escape single quotes in body
            let escaped = bodyStr.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escaped)'")
        }

        return parts.joined(separator: " \\\n  ")
    }

    /// Copy cURL to system pasteboard
    static func copyToPasteboard(_ event: NetworkEvent) {
        let command = export(event)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }
}
