import Foundation

struct BatteryInfo: Equatable {
    var percentage: Int
    var timeRemainingMinutes: Int?
    var timeOnBatteryMinutes: Int?
    var healthPercentage: Int?
    var cycleCount: Int?
    var condition: String?
    var powerMode: String?
    var isCharging: Bool
    var isOnACPower: Bool
    var powerConsumptionWatts: Double?
    var optimizedChargingState: OptimizedChargingState

    static let empty = BatteryInfo(
        percentage: 0,
        timeRemainingMinutes: nil,
        timeOnBatteryMinutes: nil,
        healthPercentage: nil,
        cycleCount: nil,
        condition: nil,
        powerMode: nil,
        isCharging: false,
        isOnACPower: false,
        powerConsumptionWatts: nil,
        optimizedChargingState: .unknown
    )
}

enum OptimizedChargingState: String {
    case engaged = "On Hold"
    case notEngaged = "Not Engaged"
    case unknown = "—"
}
