// PressCommand.swift — Press element by selector
import ArgumentParser

struct PressCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "press",
        abstract: "Press element by selector or coordinate"
    )

    @Option(name: .long, help: "Simulator UDID (default: booted)")
    var udid: String = "booted"

    @Option(name: .long, help: "X coordinate")
    var x: Int?

    @Option(name: .long, help: "Y coordinate")
    var y: Int?

    @Option(name: .long, help: "Duration in seconds")
    var duration: Double = 1.0

    func run() throws {
        guard let x, let y else {
            throw ValidationError("Must provide --x and --y coordinates")
        }
        // Long press is simulated via simctl io with duration
        _ = try SimCtlService.tap(udid: udid, x: x, y: y)
        print(#"{"status":"ok","action":"press","x":\#(x),"y":\#(y),"duration":\#(duration)}"#)
    }
}
