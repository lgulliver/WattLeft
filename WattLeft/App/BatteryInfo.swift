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
        powerConsumptionWatts: nil
    )
}
