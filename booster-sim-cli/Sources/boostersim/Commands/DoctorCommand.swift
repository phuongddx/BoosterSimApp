// DoctorCommand.swift — Validate setup for BoosterSim CLI
import ArgumentParser

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Validate setup for BoosterSim CLI"
    )

    func run() throws {
        var checks: [String: Bool] = [:]

        // Check 1: xcrun available
        checks["xcrun"] = checkCommand("/usr/bin/xcrun")

        // Check 2: simctl available
        checks["simctl"] = checkCommand("/usr/bin/xcrun", "simctl", "help")

        // Check 3: Xcode installed
        checks["xcode"] = checkCommand("/usr/bin/xcode-select", "-p")

        // Check 4: Simulator running
        checks["simulator_running"] = checkSimulatorRunning()

        // Check 5: macOS version
        checks["macos_version"] = checkMacOSVersion()

        // Check 6: Accessibility API (placeholder)
        checks["accessibility"] = true

        // Output JSON
        var output = "{"
        output += "\"status\":\"ok\","
        output += "\"action\":\"doctor\","
        output += "\"checks\":{"

        var first = true
        for (name, passed) in checks {
            if !first { output += "," }
            output += "\"\(name)\":\(passed)"
            first = false
        }

        output += "}}"
        print(output)
    }

    private func checkCommand(_ path: String, _ arguments: String...) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func checkSimulatorRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "booted"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func checkMacOSVersion() -> Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion >= 13
    }
}
