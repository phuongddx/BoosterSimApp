// ScreenshotCommand.swift — Capture screenshot from Simulator
import ArgumentParser

struct ScreenshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Capture screenshot from Simulator"
    )

    @Option(name: .long, help: "Simulator UDID (default: booted)")
    var udid: String = "booted"

    @Option(name: .long, help: "Output file path")
    var output: String = "screenshot.png"

    func run() throws {
        try SimCtlService.screenshot(udid: udid, output: output)
        print(#"{"status":"ok","action":"screenshot","output":"\#(output)"}"#)
    }
}
