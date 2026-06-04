// boostersim.swift — Main entry point for BoosterSim CLI
import ArgumentParser

@main
struct Boostersim: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "boostersim",
        abstract: "CLI tool for AI agents to control iOS Simulator",
        version: "1.0.0",
        subcommands: [
            TapCommand.self,
            SwipeCommand.self,
            TypeCommand.self,
            ScreenshotCommand.self,
            ListElementsCommand.self,
            ListDevicesCommand.self,
            PressCommand.self,
            DoctorCommand.self
        ],
        defaultSubcommand: ListDevicesCommand.self
    )
}
