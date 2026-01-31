import Foundation

enum BatteryFormatter {
    static func timeString(fromMinutes minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "—" }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }
        return "\(remainingMinutes)m"
    }

    static func healthString(fromPercentage percentage: Int?) -> String {
        guard let percentage else { return "—" }
        return "\(percentage)%"
    }

    static func conditionString(fromHealth percentage: Int?) -> String {
        guard let percentage else { return "—" }
        switch percentage {
        case 80...:
            return "Normal"
        case 60..<80:
            return "Fair"
        default:
            return "Service Recommended"
        }
    }

    static func cycleString(fromCount count: Int?) -> String {
        guard let count else { return "—" }
        return "\(count)"
    }

    static func impactString(fromValue value: Double) -> String {
        if value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
