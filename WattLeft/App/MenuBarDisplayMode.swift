import Foundation

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case percentage
    case timeRemaining

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentage:
            return "Percentage"
        case .timeRemaining:
            return "Time Remaining"
        }
    }
}
