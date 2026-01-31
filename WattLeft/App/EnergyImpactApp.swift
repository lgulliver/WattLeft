import Foundation

struct EnergyImpactApp: Identifiable, Equatable {
    let id = UUID()
    let pid: Int
    let name: String
    let impact: Double
}

struct BatterySample: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let percentage: Int
}
