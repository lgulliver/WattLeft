import AppKit
import Charts
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

            if !model.powerHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Power Consumption (since unplugged)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Chart(model.powerHistory) { sample in
                        AreaMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Watts", sample.watts)
                        )
                        .foregroundStyle(.blue.opacity(0.2))

                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Watts", sample.watts)
                        )
                        .foregroundStyle(.blue)
                    }
                    .chartYScale(domain: 0...powerChartMax)
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: powerChartAxisValues) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let watts = value.as(Double.self) {
                                    Text("\(BatteryFormatter.impactString(fromValue: watts))W")
                                }
                            }
                        }
                    }
                    .frame(height: 90)
                }
            }

            if !significantEnergyApps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Significant Energy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(significantEnergyApps) { app in
                        HStack {
                            Text(app.name)
                                .lineLimit(1)
                            Spacer()
                            Text(BatteryFormatter.impactString(fromValue: app.impact))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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

    private var significantEnergyApps: [EnergyImpactApp] {
        let threshold = 10.0
        return Array(model.energyImpactApps.filter { $0.impact >= threshold }.prefix(5))
    }

    private var powerChartMax: Double {
        let maxValue = model.powerHistory.map { $0.watts }.max() ?? 1
        return max(1, maxValue * 1.2)
    }

    private var powerChartAxisValues: [Double] {
        let maxValue = powerChartMax
        let mid = maxValue / 2
        let values = [0, mid, maxValue]
        return values
            .map { ($0 * 10).rounded() / 10 }
            .reduce(into: [Double]()) { result, value in
                if !result.contains(where: { abs($0 - value) < 0.01 }) {
                    result.append(value)
                }
            }
    }
}
