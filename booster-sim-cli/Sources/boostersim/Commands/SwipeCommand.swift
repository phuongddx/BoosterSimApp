// SwipeCommand.swift — Swipe gesture in Simulator
import ArgumentParser

struct SwipeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swipe",
        abstract: "Perform swipe gesture in Simulator"
    )

    @Option(name: .long, help: "Simulator UDID (default: booted)")
    var udid: String = "booted"

    @Option(name: .long, help: "Start X coordinate")
    var fromX: Int

    @Option(name: .long, help: "Start Y coordinate")
    var fromY: Int

    @Option(name: .long, help: "End X coordinate")
    var toX: Int

    @Option(name: .long, help: "End Y coordinate")
    var toY: Int

    func run() throws {
        try SimCtlService.swipe(udid: udid, fromX: fromX, fromY: fromY, toX: toX, toY: toY)
        print(#"{"status":"ok","action":"swipe","from":{"x":\#(fromX),"y":\#(fromY)},"to":{"x":\#(toX),"y":\#(toY)}}"#)
    }
}
