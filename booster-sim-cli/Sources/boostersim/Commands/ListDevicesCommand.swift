// ListDevicesCommand.swift — List available Simulator devices
import ArgumentParser

struct ListDevicesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-devices",
        abstract: "List available Simulator devices"
    )

    func run() throws {
        let devices = try SimCtlService.listDevices()
        let booted = devices.filter { $0.state == "Booted" }

        var output = "{"
        output += "\"status\":\"ok\","
        output += "\"action\":\"list-devices\","
        output += "\"booted_count\":\(booted.count),"
        output += "\"total_count\":\(devices.count),"
        output += "\"devices\":["

        for (index, device) in devices.enumerated() {
            if index > 0 { output += "," }
            output += "{"
            output += "\"udid\":\"\(device.udid)\","
            output += "\"name\":\"\(device.name)\","
            output += "\"state\":\"\(device.state)\""
            output += "}"
        }

        output += "]}"
        print(output)
    }
}
