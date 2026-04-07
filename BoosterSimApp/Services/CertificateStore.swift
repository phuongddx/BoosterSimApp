import Foundation
import CryptoKit
import Security

final class CertificateStore {

    private let workQueue = DispatchQueue(label: "app.booster.sim.certificates", qos: .userInitiated)

    var certURL: URL { certsDirectoryURL.appendingPathComponent("ca.pem") }

    private var keyURL: URL { certsDirectoryURL.appendingPathComponent("ca.key") }
    private var certsDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BoosterSimApp")
            .appendingPathComponent("Certificates")
    }

    func storedMetadata() -> CertificateMetadata? {
        let pathsExist = FileManager.default.fileExists(atPath: keyURL.path)
            && FileManager.default.fileExists(atPath: certURL.path)
        guard pathsExist else { return nil }
        return readMetadata(at: certURL)
    }

    func generate(completion: @escaping (Result<CertificateMetadata, CertificateError>) -> Void) {
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                guard FileManager.default.fileExists(atPath: "/usr/bin/openssl") else {
                    return DispatchQueue.main.async { completion(.failure(.opensslNotFound)) }
                }
                try self.prepareCertificatesDirectory()
                let stageURL = self.certsDirectoryURL.appendingPathComponent(".stage-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: stageURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                defer { try? FileManager.default.removeItem(at: stageURL) }
                let stageKeyURL = stageURL.appendingPathComponent("ca.key")
                let stageCertURL = stageURL.appendingPathComponent("ca.pem")
                let result = self.runOpenSSL(keyURL: stageKeyURL, certURL: stageCertURL)
                if case .failure(let error) = result {
                    return DispatchQueue.main.async { completion(.failure(error)) }
                }
                try self.installGeneratedFiles(keySource: stageKeyURL, certSource: stageCertURL)
                guard let metadata = self.readMetadata(at: self.certURL) else {
                    return DispatchQueue.main.async { completion(.failure(.invalidCertFormat)) }
                }
                DispatchQueue.main.async { completion(.success(metadata)) }
            } catch {
                let message = self.redactPaths(in: error.localizedDescription)
                DispatchQueue.main.async { completion(.failure(.opensslFailed(message))) }
            }
        }
    }

    func deleteStoredFiles() {
        try? FileManager.default.removeItem(at: keyURL)
        try? FileManager.default.removeItem(at: certURL)
    }

    func redactPaths(in message: String) -> String {
        message
            .replacingOccurrences(of: certsDirectoryURL.path, with: "<certs-dir>")
            .replacingOccurrences(of: NSHomeDirectory(), with: "~")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runOpenSSL(keyURL: URL, certURL: URL) -> Result<Void, CertificateError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", keyURL.path,
            "-out", certURL.path,
            "-days", "90",
            "-nodes",
            "-subj", "/CN=BoosterSim CA/O=BoosterSim"
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        let oldMask = umask(0o077)
        defer { umask(oldMask) }
        do {
            try process.run()
            let timeoutItem = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30, execute: timeoutItem)
            process.waitUntilExit()
            timeoutItem.cancel()
            guard process.terminationReason == .exit else { return .failure(.timeout) }
            guard process.terminationStatus == 0 else {
                let data = (process.standardError as? Pipe)?.fileHandleForReading.readDataToEndOfFile() ?? Data()
                let message = String(data: data, encoding: .utf8) ?? "OpenSSL failed."
                return .failure(.opensslFailed(redactPaths(in: message)))
            }
            return .success(())
        } catch {
            return .failure(.opensslFailed(redactPaths(in: error.localizedDescription)))
        }
    }

    private func readMetadata(at url: URL) -> CertificateMetadata? {
        guard let certData = try? Data(contentsOf: url),
              let derData = derData(fromPEM: certData),
              let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
            return nil
        }
        let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? "BoosterSim CA"
        let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [CFString: Any],
              let notAfter = values[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
              let rawValue = notAfter[kSecPropertyKeyValue] else {
            return nil
        }
        let expiry: Date
        switch rawValue {
        case let date as Date:
            expiry = date
        case let seconds as Double:
            expiry = Date(timeIntervalSinceReferenceDate: seconds)
        default:
            return nil
        }
        let fingerprint = SHA256.hash(data: SecCertificateCopyData(certificate) as Data)
            .map { String(format: "%02x", $0) }
            .joined()
        return CertificateMetadata(commonName: summary, expiry: expiry, sha256: fingerprint)
    }

    private func derData(fromPEM data: Data) -> Data? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        let base64 = string
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        return Data(base64Encoded: base64)
    }

    private func prepareCertificatesDirectory() throws {
        try FileManager.default.createDirectory(at: certsDirectoryURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: certsDirectoryURL.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directoryURL = certsDirectoryURL
        try directoryURL.setResourceValues(values)
    }

    private func installGeneratedFiles(keySource: URL, certSource: URL) throws {
        let backupKeyURL = certsDirectoryURL.appendingPathComponent("ca.key.backup")
        let backupCertURL = certsDirectoryURL.appendingPathComponent("ca.pem.backup")
        let fm = FileManager.default

        try? fm.removeItem(at: backupKeyURL)
        try? fm.removeItem(at: backupCertURL)

        do {
            if fm.fileExists(atPath: keyURL.path) { try fm.moveItem(at: keyURL, to: backupKeyURL) }
            if fm.fileExists(atPath: certURL.path) { try fm.moveItem(at: certURL, to: backupCertURL) }
            try fm.moveItem(at: keySource, to: keyURL)
            try fm.moveItem(at: certSource, to: certURL)
            try fm.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: keyURL.path)
            try fm.setAttributes([.posixPermissions: NSNumber(value: 0o600)], ofItemAtPath: certURL.path)
            try? fm.removeItem(at: backupKeyURL)
            try? fm.removeItem(at: backupCertURL)
        } catch {
            try? fm.removeItem(at: keyURL)
            try? fm.removeItem(at: certURL)
            if fm.fileExists(atPath: backupKeyURL.path) { try? fm.moveItem(at: backupKeyURL, to: keyURL) }
            if fm.fileExists(atPath: backupCertURL.path) { try? fm.moveItem(at: backupCertURL, to: certURL) }
            throw error
        }
    }
}
