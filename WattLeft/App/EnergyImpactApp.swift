import Foundation

struct EnergyImpactApp: Identifiable, Equatable {
    let id = UUID()
    let pid: Int
    let name: String
    let impact: Double
}

struct PowerSample: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let watts: Double
}
