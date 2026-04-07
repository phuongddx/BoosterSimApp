import Foundation
import Testing
@testable import BoosterSimApp

struct CertificateServiceTests {

    @Test func certificateOperationAllowsExpectedTransitions() {
        #expect(CertificateOperation.idle.canTransition(to: .generating))
        #expect(CertificateOperation.generating.canTransition(to: .error("failed")))
        #expect(CertificateOperation.error("failed").canTransition(to: .installing))
        #expect(!CertificateOperation.installing.canTransition(to: .generating))
        #expect(!CertificateOperation.resetting.canTransition(to: .rotating))
    }

    @Test func certificateStatusExposesMetadataWhenAvailable() {
        let expiry = Date(timeIntervalSince1970: 1_234_567)
        let generated = CertificateStatus.generated(cn: "BoosterSim CA", expiry: expiry, sha256: "abc")
        let installed = CertificateStatus.installed(cn: "BoosterSim CA", expiry: expiry, sha256: "def", deviceName: "iPhone", udid: "udid")
        let unknown = CertificateStatus.unknown(cn: "BoosterSim CA", expiry: expiry, sha256: "ghi", reason: "uncertain")

        #expect(generated.certificateMetadata?.commonName == "BoosterSim CA")
        #expect(installed.certificateMetadata?.sha256 == "def")
        #expect(unknown.certificateMetadata?.expiry == expiry)
        #expect(CertificateStatus.notGenerated.certificateMetadata == nil)
    }
}
