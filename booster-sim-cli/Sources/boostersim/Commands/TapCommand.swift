// TapCommand.swift — Tap at coordinates or by selector
import ArgumentParser

struct TapCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Tap at coordinates in Simulator"
    )

    @Option(name: .long, help: "Simulator UDID (default: booted)")
    var udid: String = "booted"

    @Option(name: .long, help: "X coordinate")
    var x: Int

    @Option(name: .long, help: "Y coordinate")
    var y: Int

    func run() throws {
        try SimCtlService.tap(udid: udid, x: x, y: y)
        print(#"{"status":"ok","action":"tap","x":\#(x),"y":\#(y)}"#)
    }
}
