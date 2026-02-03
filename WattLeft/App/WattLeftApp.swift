import AppKit
import SwiftUI

@main
struct WattLeftApp: App {
    @StateObject private var model = BatteryModel()
    @AppStorage("menuBarDisplayMode") private var displayModeRaw = MenuBarDisplayMode.percentage.rawValue

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model, displayMode: displayModeBinding)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: batteryIconName)
                Text(displayText)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var displayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: displayModeRaw) ?? .percentage
    }

    private var displayModeBinding: Binding<MenuBarDisplayMode> {
        Binding(
            get: { displayMode },
            set: { displayModeRaw = $0.rawValue }
        )
    }

    private var displayText: String {
        switch displayMode {
        case .percentage:
            return "\(model.info.percentage)%"
        case .timeRemaining:
            return BatteryFormatter.timeString(fromMinutes: model.info.timeRemainingMinutes)
        }
    }

    private var batteryIconName: String {
        let percentage = model.info.percentage
        let base: String
        switch percentage {
        case ..<10:
            base = "battery.0"
        case ..<35:
            base = "battery.25"
        case ..<60:
            base = "battery.50"
        case ..<85:
            base = "battery.75"
        default:
            base = "battery.100"
        }
        if model.info.isCharging {
            let chargingCandidates = ["\(base).bolt", "battery.100.bolt", "bolt.fill", base]
            return firstAvailableSymbol(from: chargingCandidates) ?? base
        }
        return base
    }

    private func firstAvailableSymbol(from candidates: [String]) -> String? {
        for name in candidates where symbolExists(name) {
            return name
        }
        return nil
    }

    private func symbolExists(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}
