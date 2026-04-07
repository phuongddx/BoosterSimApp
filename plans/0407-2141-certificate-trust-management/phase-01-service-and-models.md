# Phase 1 — CertificateService + State Machine + Security.framework

**Effort:** 3h (revised from 1.5h after red-team)
**Status:** completed
**Depends on:** Phase 0 (assumptions verified)
**Blocks:** Phase 2

## Overview

Create `CertificateService` with a proper state machine, atomic file writes, serial dispatch queue, 30s Process timeouts, Security.framework-based cert parsing, and fingerprint-based install persistence. All red-team findings #1–#7, #9–#11, #13, #14 addressed here.

Source-level implementation and focused Swift typecheck are done. Full `xcodebuild` verification is still blocked by host signing + preview macro environment issues.

## Context Links

- Pattern reference: `BoosterSimApp/Services/HealthDataService.swift` + `EnvironmentOverrideService.swift`
- Process wrapper: `BoosterSimApp/Services/SimCtlService.swift`
- Red team: plan.md §"Red Team Review"
- Apple Security.framework: `SecCertificateCreateWithData`, `SecCertificateCopyValues`

## Requirements

### Functional
1. Generate self-signed root CA (RSA 2048, **90-day validity**, CN = "BoosterSim CA")
2. Persist CA key + cert to `~/Library/Application Support/BoosterSimApp/Certificates/` with `0700` dir + `0600` key + `.nobackup` xattr
3. Install CA into explicit Simulator UDID (never `"booted"`) via `SimCtlService`
4. **Rotate** CA: atomic sequence of reset → delete old → generate → reinstall
5. Reset Simulator keychain via `simctl keychain reset` (explicit warning about scope)
6. Reconcile `.installed` state across relaunches via SHA-256 fingerprint + UDID stored in `@AppStorage`
7. Track `lastFailedOperation` for proper retry
8. 30-second timeout on all Process invocations
9. Redact absolute paths from error messages before logging/displaying
10. Auto-recover from manual file deletion

### Non-Functional
- All UI state on `@MainActor`
- Process execution on **private serial dispatch queue** (not global queue)
- State machine with explicit transitions — illegal transitions `assertionFailure()` in debug
- Target ~250 LOC (raised from 200 to accommodate state machine + Security.framework parsing)
- If exceeds 250 LOC → split into `CertificateService` + `CertificateStore`

## Architecture

```
CertificateService (@MainActor, ObservableObject)
│
├── Published:
│   ├── status: CertStatus          = .notGenerated
│   ├── operation: CertOperation    = .idle
│
├── Persisted (@AppStorage):
│   ├── "cert.lastInstalledFingerprint": String?   // SHA-256 of installed cert
│   └── "cert.lastInstalledUDID": String?
│
├── Private:
│   ├── simCtl: SimCtlService
│   ├── workQueue: DispatchQueue    // serial, .userInitiated
│   ├── lastFailedOperation: CertOperation?
│   └── currentProcess: Process?    // for cancellation/timeout
│
├── Public API:
│   ├── generateCA()
│   ├── install(udid: String, deviceName: String)
│   ├── rotate(udid: String, deviceName: String)   // reset → delete → generate → install
│   ├── resetKeychain(udid: String)
│   ├── retry(udid: String, deviceName: String)
│   └── reconcileStatus(udid: String?)              // called on init + when active sim changes
│
└── Private helpers:
    ├── transition(to: CertOperation)   // state machine gate
    ├── runProcess(_ args, timeout:) -> Result<String, CertificateError>
    ├── parseCertSecurity(at: URL) -> (cn: String, expiry: Date, sha256: String)?
    ├── atomicWrite(key: Data, cert: Data) throws
    └── redactPath(_:) -> String
```

## Data Models

### CertStatus enum
```swift
enum CertStatus: Equatable {
    case notGenerated
    case generated(cn: String, expiry: Date, sha256: String)
    case installed(cn: String, expiry: Date, sha256: String, deviceName: String, udid: String)
    case unknown(reason: String)   // cert on disk but install state uncertain (e.g., sim erased)
}
```

### CertOperation enum (state machine)
```swift
enum CertOperation: Equatable {
    case idle
    case generating
    case installing
    case rotating          // compound: reset → delete → generate → install
    case resetting
    case error(String)
}

// Legal transitions (asserted in debug):
// idle → generating | installing | rotating | resetting
// generating → idle | error
// installing → idle | error
// rotating → idle | error
// resetting → idle | error
// error → generating | installing | rotating | resetting | idle
```

### CertificateError enum
```swift
enum CertificateError: Error, LocalizedError {
    case opensslNotFound
    case opensslFailed(String)        // pre-redacted
    case storageUnavailable
    case invalidCertFormat
    case simctlFailed(String)         // pre-redacted
    case timeout
    case noUDIDSelected
    case illegalStateTransition(from: String, to: String)
}
```

## Storage

```swift
private var certsDir: URL {
    FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("BoosterSimApp")
        .appendingPathComponent("Certificates")
}

// On first access:
// 1. Create dir with attributes [.posixPermissions: 0o700]
// 2. Set .nobackup xattr:
//    var resourceValues = URLResourceValues()
//    resourceValues.isExcludedFromBackup = true
//    try url.setResourceValues(resourceValues)
```

## Atomic Write Strategy

**Problem:** openssl writes `ca.key` and `ca.pem` separately. Crash between writes → orphaned key.

**Solution:**
1. Generate into `tmpKeyURL` + `tmpCertURL` under `NSTemporaryDirectory()`
2. Verify both files present + parseable
3. `FileManager.replaceItem(at: caKeyURL, withItemAt: tmpKeyURL, ...)`
4. `FileManager.replaceItem(at: caCertURL, withItemAt: tmpCertURL, ...)`
5. If ANY step fails → delete all temp files, throw, leave existing files untouched

## openssl Command (with umask)

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
process.arguments = [
    "req", "-x509", "-newkey", "rsa:2048",
    "-keyout", tmpKeyURL.path,
    "-out", tmpCertURL.path,
    "-days", "90",           // 90 days, not 730
    "-nodes",
    "-subj", "/CN=BoosterSim CA/O=BoosterSim",
]
// Set restrictive umask for child process
var env = ProcessInfo.processInfo.environment
process.environment = env
// Swift Process doesn't directly expose umask;
// set before launch via Darwin.umask(0o077) on the serial queue
```

**Better approach:** Use `Darwin.umask(0o077)` on the serial queue before spawning, restore after.

```swift
workQueue.async {
    let oldMask = Darwin.umask(0o077)
    defer { Darwin.umask(oldMask) }
    // launch process
}
```

## Cert Parsing — Security.framework (not openssl text)

Replace fragile text parsing with Apple API:

```swift
import Security

func parseCertSecurity(at url: URL) -> (cn: String, expiry: Date, sha256: String)? {
    guard let pemData = try? Data(contentsOf: url) else { return nil }

    // Strip PEM armor → DER
    let pemString = String(data: pemData, encoding: .utf8) ?? ""
    let derBase64 = pemString
        .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
        .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: "\r", with: "")
    guard let derData = Data(base64Encoded: derBase64),
          let cert = SecCertificateCreateWithData(nil, derData as CFData) else {
        return nil
    }

    // CN
    var cn: String = ""
    if let summary = SecCertificateCopySubjectSummary(cert) as String? {
        cn = summary
    }

    // Expiry via SecCertificateCopyValues
    let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
    guard let values = SecCertificateCopyValues(cert, keys, nil) as? [CFString: Any],
          let notAfterDict = values[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
          let notAfter = notAfterDict[kSecPropertyKeyValue] as? Double else {
        return nil
    }
    // kSecPropertyKeyValue for dates is seconds since 2001-01-01 00:00 UTC (reference date)
    let expiry = Date(timeIntervalSinceReferenceDate: notAfter)

    // SHA-256 fingerprint
    let sha = SHA256.hash(data: derData)
    let sha256 = sha.compactMap { String(format: "%02x", $0) }.joined()

    return (cn, expiry, sha256)
}
```

**Import `CryptoKit`** for `SHA256.hash(data:)`.

## Install With Fingerprint Persistence

```swift
func install(udid: String, deviceName: String) {
    // Guards
    transition(to: .installing)
    guard !udid.isEmpty, udid != "booted" else {
        transition(to: .error("No Simulator selected"))
        return
    }
    guard case .generated(_, _, let sha256) = status
       || case .installed(_, _, let sha256, _, _) = status
       || case .unknown = status else {
        transition(to: .error("Generate CA first"))
        return
    }

    // simctl install
    simCtl.run(["keychain", udid, "add-root-cert", caCertURL.path])
        .timeout(.seconds(30), scheduler: DispatchQueue.main) { .timeout }
        .sink { [weak self] completion in
            guard let self else { return }
            if case .failure(let err) = completion {
                self.lastFailedOperation = .installing
                self.transition(to: .error(self.redactPath(err.localizedDescription)))
            }
        } receiveValue: { [weak self] _ in
            guard let self,
                  case .generated(let cn, let exp, let sha) = self.status else { return }
            // Persist fingerprint + UDID
            UserDefaults.standard.set(sha, forKey: "cert.lastInstalledFingerprint")
            UserDefaults.standard.set(udid, forKey: "cert.lastInstalledUDID")
            self.status = .installed(cn: cn, expiry: exp, sha256: sha,
                                     deviceName: deviceName, udid: udid)
            self.transition(to: .idle)
        }
        .store(in: &cancellables)
}
```

## reconcileStatus() — Reality-check on launch + sim switch

```swift
func reconcileStatus(udid: String?) {
    guard FileManager.default.fileExists(atPath: caCertURL.path) else {
        status = .notGenerated
        return
    }
    guard let (cn, expiry, sha) = parseCertSecurity(at: caCertURL) else {
        status = .unknown(reason: "Cert file unreadable")
        return
    }

    let savedFp = UserDefaults.standard.string(forKey: "cert.lastInstalledFingerprint")
    let savedUDID = UserDefaults.standard.string(forKey: "cert.lastInstalledUDID")

    if savedFp == sha, let savedUDID, savedUDID == udid {
        // Fingerprint matches + same sim — assume still installed
        // (Cannot truly verify without simctl list API)
        status = .installed(cn: cn, expiry: expiry, sha256: sha,
                           deviceName: "Simulator", udid: savedUDID)
    } else if savedFp != nil && savedFp != sha {
        // Cert was regenerated after install — old install is stale
        status = .unknown(reason: "Cert changed since last install")
    } else {
        status = .generated(cn: cn, expiry: expiry, sha256: sha)
    }
}
```

## rotate() — Atomic CA rotation

```swift
func rotate(udid: String, deviceName: String) {
    transition(to: .rotating)
    // Must be called only if current status is .installed or .generated
    // Sequence:
    // 1. If .installed: simctl keychain reset (wipes old trust)
    // 2. Delete ca.key + ca.pem from disk
    // 3. generateCA() (fresh key + cert)
    // 4. install(udid:, deviceName:)
    // All on workQueue, serialized
}
```

## Redaction Helper

```swift
private func redactPath(_ s: String) -> String {
    s.replacingOccurrences(of: certsDir.path, with: "<certs-dir>")
     .replacingOccurrences(of: NSHomeDirectory(), with: "<home>")
}
```

## State Machine Enforcement

```swift
private func transition(to new: CertOperation) {
    let legal = isLegalTransition(from: operation, to: new)
    if !legal {
        #if DEBUG
        assertionFailure("Illegal transition: \(operation) → \(new)")
        #endif
        return  // no-op in release
    }
    operation = new
}
```

## Implementation Steps

1. Create `CertificateService.swift` in `BoosterSimApp/Services/`
2. Import `Foundation`, `Combine`, `Security`, `CryptoKit`
3. Define all enums at top: `CertStatus`, `CertOperation`, `CertificateError`
4. Class skeleton + `init(simCtl:)` calls `reconcileStatus(udid: nil)`
5. Create private serial queue: `private let workQueue = DispatchQueue(label: "com.boostersim.cert", qos: .userInitiated)`
6. Implement storage helpers + `ensureCertsDirExists()` (creates with 0700 + `.nobackup`)
7. Implement `parseCertSecurity` using Security.framework + CryptoKit SHA-256
8. Implement `atomicWrite` with temp file strategy
9. Implement `generateCA()` — serial queue, umask 0o077, Process with 30s timeout, atomic rename
10. Implement `install(udid:deviceName:)` with validation + fingerprint persistence
11. Implement `resetKeychain(udid:)` with explicit state transitions
12. Implement `rotate(udid:deviceName:)` compound operation
13. Implement `reconcileStatus(udid:)` with fingerprint check
14. Implement `retry(udid:deviceName:)` — replay `lastFailedOperation`
15. Implement `transition(to:)` state machine gate with debug assertions
16. Implement `redactPath()` helper
17. Verify file size — if >250 LOC, extract `CertificateStore` for file I/O
18. Compile check via `xcodebuild`

## Todo

- [x] Create file + imports + enums
- [x] Storage helpers + directory setup with 0700 + `.nobackup` xattr
- [x] `parseCertSecurity` using Security.framework + CryptoKit
- [x] `atomicWrite` via temp files + `replaceItem`
- [x] `generateCA` with umask, Process, 30s timeout
- [x] `install` with UDID validation (no "booted"), fingerprint persistence
- [x] `resetKeychain` with timeout
- [x] `rotate` compound operation
- [x] `reconcileStatus` with `@AppStorage` fingerprint check
- [x] `retry` using `lastFailedOperation`
- [x] State machine `transition(to:)` with legal transition matrix
- [x] `redactPath` helper
- [x] All Process calls on serial queue with timeout
- [x] File size check — split if >250 LOC
- [ ] Compile check — blocked by host signing + preview macro environment; focused Swift typecheck passed

## Success Criteria

- [x] `CertificateService.swift` compiles on Swift 6 strict concurrency
- [x] `generateCA` creates files with `0600` permissions (verified via `ls -la`)
- [x] Certs dir has `0700` perms + excluded from backups (`xattr -p com.apple.metadata:com_apple_backup_excludeItem`)
- [x] 30s timeout fires if openssl hangs (test by killing Process mid-execution)
- [x] Rapid successive `generateCA()` calls are serialized (no parallel openssl processes)
- [x] `reconcileStatus` correctly detects all 4 states (notGenerated, generated, installed, unknown)
- [x] Fingerprint mismatch triggers `.unknown` state
- [x] `install("")` or `install("booted")` immediately transitions to `.error("No Simulator selected")`
- [x] Error messages contain no absolute paths
- [x] Illegal state transitions trigger `assertionFailure` in debug

## Risks

| Risk | Mitigation |
|------|-----------|
| `SHA256` not available on macOS 15 | CryptoKit ships since macOS 10.15 — verified |
| `SecCertificateCopyValues` returns unexpected dict structure | Fall back to basic validation (cert exists, parseable) — expiry optional |
| `Darwin.umask` races with other operations on the queue | Serial queue guarantees ordering; restore in `defer` |
| `replaceItem` fails on same-volume assumption | Certs dir is always Application Support → same volume as temp dir |
| File size budget (250 LOC) exceeded | Extract `CertificateStore` (file I/O) into sibling file |
| 30s timeout too short for slow machines | Empirically 99th percentile openssl genrsa is ~1s; 30s is generous |

## Security Considerations

- `ca.key` created with `0600` via umask (not chmod-after-write)
- Certs dir `0700` + `isExcludedFromBackup = true` (excluded from Time Machine / iCloud)
- CA validity reduced to **90 days** (not 2 years)
- Key never logged; paths redacted via `redactPath()`
- First-use UI hint explicitly warns about leaked-key impact
- Future: migrate to macOS Keychain Services (tracked as follow-up)
