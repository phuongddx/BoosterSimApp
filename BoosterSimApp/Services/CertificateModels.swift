import Foundation

struct CertificateMetadata: Equatable {
    let commonName: String
    let expiry: Date
    let sha256: String
}

enum CertificateStatus: Equatable {
    case notGenerated
    case generated(cn: String, expiry: Date, sha256: String)
    case installed(cn: String, expiry: Date, sha256: String, deviceName: String, udid: String)
    case unknown(cn: String, expiry: Date, sha256: String, reason: String)

    var certificateMetadata: CertificateMetadata? {
        switch self {
        case .notGenerated:
            nil
        case .generated(let cn, let expiry, let sha256),
             .installed(let cn, let expiry, let sha256, _, _),
             .unknown(let cn, let expiry, let sha256, _):
            CertificateMetadata(commonName: cn, expiry: expiry, sha256: sha256)
        }
    }
}

enum CertificateOperation: Equatable {
    case idle
    case generating
    case installing
    case rotating
    case resetting
    case error(String)

    var isWorking: Bool {
        switch self {
        case .idle, .error:
            false
        default:
            true
        }
    }

    func canTransition(to next: CertificateOperation) -> Bool {
        switch self {
        case .idle:
            switch next {
            case .idle, .generating, .installing, .rotating, .resetting:
                return true
            case .error:
                return false
            }
        case .generating, .installing, .rotating, .resetting:
            if case .idle = next { return true }
            if case .error = next { return true }
            return false
        case .error:
            if case .idle = next { return true }
            if case .generating = next { return true }
            if case .installing = next { return true }
            if case .rotating = next { return true }
            if case .resetting = next { return true }
            return false
        }
    }
}

enum CertificateError: LocalizedError {
    case invalidCertFormat
    case noUDIDSelected
    case noCertificateOnDisk
    case opensslFailed(String)
    case simctlFailed(String)
    case opensslNotFound
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidCertFormat:
            "Certificate format is invalid."
        case .noUDIDSelected:
            "No active Simulator selected."
        case .noCertificateOnDisk:
            "Generate a CA first."
        case .opensslFailed(let message):
            message
        case .simctlFailed(let message):
            message
        case .opensslNotFound:
            "OpenSSL was not found at /usr/bin/openssl."
        case .timeout:
            "Operation timed out."
        }
    }
}
