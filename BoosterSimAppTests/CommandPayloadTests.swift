import Foundation
import Testing
@testable import BoosterSimApp

struct CommandPayloadTests {

    // MARK: - Snapshot Round-Trip

    @Test func boosterCommandRoundTripsLosslessly() throws {
        let command = BoosterCommand(
            airplane: true,
            throttle: ThrottleSpec(latencyMs: 400, downloadKbps: 750, uploadKbps: nil),
            blockRules: [
                BlockRule(id: UUID(), domain: "*.example.com", pathPrefix: "/api", isEnabled: true)
            ]
        )

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(BoosterCommand.self, from: data)

        #expect(decoded == command)
        #expect(decoded.version == BoosterCommand.version)
    }

    @Test func nilThrottleRoundTrips() throws {
        let command = BoosterCommand(airplane: false, throttle: nil, blockRules: [])

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(BoosterCommand.self, from: data)

        #expect(decoded.throttle == nil)
        #expect(decoded.blockRules.isEmpty)
    }

    // MARK: - Version Gate

    @Test func futureVersionFrameIsIgnoredWithoutPartialApplication() throws {
        let futureJSON = """
        {"version": \(BoosterCommand.version + 1), "airplane": true, "throttle": null, "blockRules": []}
        """
        let decoded = try JSONDecoder().decode(BoosterCommand.self, from: Data(futureJSON.utf8))

        // Client decode path: snapshots from an unknown schema version are ignored whole.
        var applied = BoosterCommand(airplane: false)
        if BoosterCommand.isKnownVersion(decoded.version) {
            applied = decoded
        }

        #expect(!BoosterCommand.isKnownVersion(decoded.version))
        #expect(applied.airplane == false)
    }

    // MARK: - Length-Prefix Framing

    @Test func frameRoundTripsEmptyBody() throws {
        var buffer = CommandFrame.encode(Data())

        let payload = try CommandFrame.decodeOne(from: &buffer)

        #expect(payload.isEmpty)
        #expect(buffer.isEmpty)
    }

    @Test func frameRoundTripsSingleByteBody() throws {
        var buffer = CommandFrame.encode(Data([0x7F]))

        let payload = try CommandFrame.decodeOne(from: &buffer)

        #expect(payload == Data([0x7F]))
        #expect(buffer.isEmpty)
    }

    @Test func frameReassemblesAcrossPartialReads() throws {
        let frame = CommandFrame.encode(Data("snapshot body".utf8))

        // First partial read: only the length prefix plus one body byte arrives.
        var buffer = Data(frame.prefix(CommandFrame.prefixLength + 1))
        #expect(throws: CommandFrame.DecodeError.incomplete) {
            try CommandFrame.decodeOne(from: &buffer)
        }

        // Second partial read completes the frame.
        buffer.append(frame.suffix(frame.count - (CommandFrame.prefixLength + 1)))

        let payload = try CommandFrame.decodeOne(from: &buffer)
        #expect(payload == Data("snapshot body".utf8))
        #expect(buffer.isEmpty)
    }
}
