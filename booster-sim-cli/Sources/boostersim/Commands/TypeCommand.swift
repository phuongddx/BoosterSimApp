// TypeCommand.swift — Type text in Simulator
import ArgumentParser

struct TypeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text in Simulator"
    )

    @Option(name: .long, help: "Simulator UDID (default: booted)")
    var udid: String = "booted"

    @Argument(help: "Text to type")
    var text: String

    func run() throws {
        try SimCtlService.type(udid: udid, text: text)
        print(#"{"status":"ok","action":"type","text":"\#(text)"}"#)
    }
}
