import Foundation

struct EnergyImpactApp: Identifiable, Equatable {
    let id = UUID()
    let pid: Int
    let name: String
    let impact: Double
}

struct EnergyImpactAppSummary: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let totalImpact: Double
}

struct PowerSample: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let watts: Double
}
