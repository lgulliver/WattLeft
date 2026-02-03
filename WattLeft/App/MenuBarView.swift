import AppKit
import Charts
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: BatteryModel
    @Binding var displayMode: MenuBarDisplayMode
    private let menuWidth: CGFloat = 320
    private let menuHeight: CGFloat = 520

    var body: some View {
        scrollableContent(combinedContent)
            .font(.system(size: 12))
            .controlSize(.small)
            .frame(width: menuWidth, height: menuHeight)
    }

    private func scrollableContent<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private var combinedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WattLeft")
                .font(.system(size: 14, weight: .semibold))

            Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                tableRow("Charge", value: "\(model.info.percentage)%")
                tableRow(model.info.isOnACPower ? "Time to full" : "Time remaining",
                         value: BatteryFormatter.timeString(fromMinutes: model.info.timeRemainingMinutes))
                tableRow("Status", value: statusText)
                tableRow("Optimized Charging", value: model.info.optimizedChargingState.rawValue)
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
                sectionHeader("Power Consumption", subtitle: "Since unplugged")

                VStack(alignment: .leading, spacing: 6) {

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

            if model.energyImpactMetric == .power, !significantEnergyApps.isEmpty {
                sectionHeader("Significant Energy")

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(significantEnergyApps) { app in
                        appRow(title: app.name, value: BatteryFormatter.impactString(fromValue: app.impact), pid: app.pid)
                    }
                }
            }

            if !model.info.isOnACPower || !model.energyImpactApps.isEmpty {
                Divider()

                sectionHeader("Apps")

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(model.energyImpactMetric.liveTitle)
                            Text("W")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if model.energyImpactApps.isEmpty {
                            Text("No active energy impact data.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(liveEnergyApps) { app in
                                appRow(title: app.name, value: liveImpactValue(for: app.impact), pid: app.pid)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Since Unplugged")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if model.info.isOnACPower {
                            Text("Totals reset while plugged in.")
                                .foregroundStyle(.secondary)
                        } else if model.energyImpactTotals.isEmpty {
                            Text("Collecting impact since unplugged…")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(cumulativeEnergyApps) { app in
                                appRow(
                                    title: app.name,
                                    value: "\(BatteryFormatter.impactString(fromValue: app.totalImpact)) impact-min"
                                )
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Battery Settings…") {
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
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .monospacedDigit()
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func appRow(title: String, value: String, pid: Int? = nil) -> some View {
        HStack {
            Image(nsImage: appIcon(for: pid, name: title))
                .resizable()
                .frame(width: 16, height: 16)
                .cornerRadius(3)
                .help(title)
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            Text(value)
                .monospacedDigit()
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func liveImpactValue(for value: Double) -> String {
        "\(BatteryFormatter.impactString(fromValue: value))W"
    }

    private func appIcon(for pid: Int?, name: String) -> NSImage {
        if let pid,
           let icon = NSRunningApplication(processIdentifier: pid_t(pid))?.icon {
            return icon
        }

        if let icon = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame
        })?.icon {
            return icon
        }

        return NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var liveEnergyApps: [EnergyImpactApp] {
        Array(model.energyImpactApps.prefix(5))
    }

    private var cumulativeEnergyApps: [EnergyImpactAppSummary] {
        Array(model.energyImpactTotals.prefix(5))
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
