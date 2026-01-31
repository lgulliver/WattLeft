import Foundation
import IOKit
import IOKit.ps

final class BatteryReader {
    func readBatteryInfo() -> BatteryInfo? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        let sources = (IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]) ?? []
        let registry = readRegistryDiagnostics()

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let info = BatteryReader.batteryInfo(from: description, registry: registry) {
                return info
            }
        }

        return nil
    }

    func readEnergyImpactApps() -> [EnergyImpactApp] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        task.arguments = ["-l", "1", "-o", "power", "-stats", "pid,command,power"]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
        } catch {
            return []
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return [] }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return BatteryReader.energyImpactApps(fromTopOutput: output)
    }

    static func batteryInfo(from description: [String: Any]) -> BatteryInfo? {
        return batteryInfo(from: description, registry: nil)
    }

    private static func batteryInfo(from description: [String: Any], registry: [String: Any]?) -> BatteryInfo? {
        guard let type = description[kIOPSTypeKey] as? String,
              type == kIOPSInternalBatteryType else {
            return nil
        }

        let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int
            ?? registry?["CurrentCapacity"] as? Int
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Int
            ?? registry?["MaxCapacity"] as? Int

        guard let currentCapacity,
              let maxCapacity,
              maxCapacity > 0 else {
            return nil
        }

        let percentage = Int(round((Double(currentCapacity) / Double(maxCapacity)) * 100.0))

        let powerSourceState = description[kIOPSPowerSourceStateKey] as? String
        let isOnACPower = powerSourceState == kIOPSACPowerValue
        let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false

        let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
        let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int
        let timeRemainingMinutes: Int?
        if isOnACPower {
            timeRemainingMinutes = (timeToFull ?? 0) > 0 ? timeToFull : nil
        } else {
            timeRemainingMinutes = (timeToEmpty ?? 0) > 0 ? timeToEmpty : nil
        }

        var healthPercentage: Int?
        let designCapacityPS = description[kIOPSDesignCapacityKey] as? Int
        let maxCapacityPS = description[kIOPSMaxCapacityKey] as? Int
        let designCapacityReg = registry?["DesignCapacity"] as? Int
        let appleRawMax = registry?["AppleRawMaxCapacity"] as? Int
        let nominalCharge = registry?["NominalChargeCapacity"] as? Int

        if let designCapacityReg, designCapacityReg > 0,
           let appleRawMax, appleRawMax > 0 {
            let health = Int((Double(appleRawMax) / Double(designCapacityReg)) * 100.0)
            healthPercentage = max(0, min(100, health))
        } else if let designCapacityReg, designCapacityReg > 0,
                  let nominalCharge, nominalCharge > 0 {
            let health = Int((Double(nominalCharge) / Double(designCapacityReg)) * 100.0)
            healthPercentage = max(0, min(100, health))
        } else if let designCapacityPS, let maxCapacityPS, designCapacityPS > 0 {
            let health = Int((Double(maxCapacityPS) / Double(designCapacityPS)) * 100.0)
            healthPercentage = max(0, min(100, health))
        }

        let cycleCount = description["Cycle Count"] as? Int
            ?? description["CycleCount"] as? Int
            ?? registry?["CycleCount"] as? Int

        let rawCondition = (description[kIOPSBatteryHealthConditionKey] as? String)
            ?? (description[kIOPSBatteryHealthKey] as? String)
            ?? (registry?["BatteryHealthCondition"] as? String)
            ?? (registry?["BatteryHealth"] as? String)

        let condition = (rawCondition?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? rawCondition
            : BatteryFormatter.conditionString(fromHealth: healthPercentage)

        let powerMode = BatteryReader.readPowerMode()
        let powerConsumptionWatts = BatteryReader.powerConsumptionWatts(fromRegistry: registry)

        return BatteryInfo(
            percentage: percentage,
            timeRemainingMinutes: timeRemainingMinutes,
            timeOnBatteryMinutes: nil,
            healthPercentage: healthPercentage,
            cycleCount: cycleCount,
            condition: condition,
            powerMode: powerMode,
            isCharging: isCharging,
            isOnACPower: isOnACPower,
            powerConsumptionWatts: powerConsumptionWatts
        )
    }

    private func readRegistryDiagnostics() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS else { return nil }
        return properties?.takeRetainedValue() as? [String: Any]
    }

    static func readPowerMode() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g"]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
        } catch {
            return nil
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        return BatteryReader.powerMode(fromPMSetOutput: output)
    }

    static func powerMode(fromPMSetOutput output: String) -> String? {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("powermode") else { continue }
            let normalized = trimmed.replacingOccurrences(of: "\\t", with: "\t")
            let parts = normalized.split(omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else { continue }
            let rawValue = String(parts[1])
            switch rawValue {
            case "0":
                return "Automatic"
            case "1":
                return "Low Power"
            case "2":
                return "High Power"
            default:
                return rawValue
            }
        }
        return nil
    }

    static func powerConsumptionWatts(fromRegistry registry: [String: Any]?) -> Double? {
        guard let registry else { return nil }

        let amperage = (registry["InstantAmperage"] as? Int)
            ?? (registry["Amperage"] as? Int)
        let voltage = registry["Voltage"] as? Int

        guard let amperage, let voltage, voltage > 0 else { return nil }
        let watts = (Double(abs(amperage)) * Double(voltage)) / 1_000_000.0
        return watts > 0 ? watts : nil
    }

    static func energyImpactApps(fromTopOutput output: String) -> [EnergyImpactApp] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        guard let headerIndex = lines.firstIndex(where: { $0.contains("PID") && $0.contains("COMMAND") && $0.contains("POWER") }) else {
            return []
        }

        let dataLines = lines[(headerIndex + 1)...]
        var apps: [EnergyImpactApp] = []
        apps.reserveCapacity(10)

        for line in dataLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 3 else { continue }

            guard let pid = Int(parts[0]) else { continue }
            guard let impact = Double(parts.last ?? "") else { continue }
            let nameParts = parts.dropFirst().dropLast()
            let name = nameParts.joined(separator: " ")
            guard name.isEmpty == false else { continue }
            guard impact > 0 else { continue }

            apps.append(EnergyImpactApp(pid: pid, name: name, impact: impact))
        }

        return apps
            .sorted { $0.impact > $1.impact }
    }
}
