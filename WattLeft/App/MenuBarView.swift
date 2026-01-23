import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: BatteryModel
    @Binding var displayMode: MenuBarDisplayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WattLeft")
                .font(.headline)

            Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                tableRow("Charge", value: "\(model.info.percentage)%")
                tableRow(model.info.isOnACPower ? "Time to full" : "Time remaining",
                         value: BatteryFormatter.timeString(fromMinutes: model.info.timeRemainingMinutes))
                tableRow("Status", value: statusText)
                if !model.info.isOnACPower {
                    tableRow("On battery for",
                             value: BatteryFormatter.timeString(fromMinutes: model.info.timeOnBatteryMinutes))
                }
                tableRow("Cycles", value: BatteryFormatter.cycleString(fromCount: model.info.cycleCount))
                tableRow("Battery Condition", value: model.info.condition ?? "—")
                tableRow("Maximum Capacity",
                         value: BatteryFormatter.healthString(fromPercentage: model.info.healthPercentage))
                tableRow("Power Mode", value: model.info.powerMode ?? "—")
            }

            Divider()

            Button("Power Mode Settings…") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.battery") {
                    NSWorkspace.shared.open(url)
                }
            }

            Toggle("Launch at Login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Picker("Menu Bar Display", selection: $displayMode) {
                ForEach(MenuBarDisplayMode.allCases) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Divider()

            Button("Quit WattLeft") {
                NSApp.terminate(nil)
            }
        }
        .font(.system(size: 13))
        .padding(12)
        .frame(width: 300)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var statusText: String {
        if model.info.isCharging {
            return "Charging"
        }
        if model.info.isOnACPower {
            return "On AC Power"
        }
        return "On Battery"
    }

    @ViewBuilder
    private func tableRow(_ title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
