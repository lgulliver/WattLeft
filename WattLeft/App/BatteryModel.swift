import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class BatteryModel: ObservableObject {
    @Published private(set) var info: BatteryInfo = .empty
    @Published private(set) var launchAtLogin = false
    @Published private(set) var energyImpactApps: [EnergyImpactApp] = []
    @Published private(set) var batteryHistory: [BatterySample] = []

    private let reader = BatteryReader()
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    private let lastUnpluggedKey = "WattLeft.lastUnpluggedAt"
    private let lastOnACKey = "WattLeft.lastOnACPower"
    private var lastUnpluggedAt: Date?
    private var lastWasOnACPower: Bool?
    private let maxHistorySamples = 720

    init() {
        launchAtLogin = isLaunchAtLoginEnabled()
        if let timestamp = defaults.object(forKey: lastUnpluggedKey) as? TimeInterval {
            lastUnpluggedAt = Date(timeIntervalSince1970: timestamp)
        }
        if defaults.object(forKey: lastOnACKey) != nil {
            lastWasOnACPower = defaults.bool(forKey: lastOnACKey)
        }
        refresh()
        startTimer()
    }

    func refresh() {
        guard var nextInfo = reader.readBatteryInfo() else {
            info = .empty
            return
        }
        updateUnpluggedTracking(isOnACPower: nextInfo.isOnACPower)
        nextInfo.timeOnBatteryMinutes = timeOnBatteryMinutes()
        info = nextInfo
        energyImpactApps = reader.readEnergyImpactApps()
        updateBatteryHistory(percentage: nextInfo.percentage, isOnACPower: nextInfo.isOnACPower)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.invalidate()
        }
    }

    private func updateUnpluggedTracking(isOnACPower: Bool) {
        if isOnACPower {
            lastUnpluggedAt = nil
        } else if lastWasOnACPower != false {
            lastUnpluggedAt = Date()
        }

        if let lastUnpluggedAt {
            defaults.set(lastUnpluggedAt.timeIntervalSince1970, forKey: lastUnpluggedKey)
        } else {
            defaults.removeObject(forKey: lastUnpluggedKey)
        }

        lastWasOnACPower = isOnACPower
        defaults.set(isOnACPower, forKey: lastOnACKey)
    }

    private func timeOnBatteryMinutes() -> Int? {
        guard let lastUnpluggedAt else { return nil }
        let interval = Date().timeIntervalSince(lastUnpluggedAt)
        guard interval >= 0 else { return nil }
        return Int(interval / 60)
    }

    private func updateBatteryHistory(percentage: Int, isOnACPower: Bool) {
        if isOnACPower {
            if !batteryHistory.isEmpty {
                batteryHistory = []
            }
            return
        }

        let now = Date()
        if let last = batteryHistory.last,
           Calendar.current.isDate(last.timestamp, equalTo: now, toGranularity: .minute),
           last.percentage == percentage {
            return
        }

        batteryHistory.append(BatterySample(timestamp: now, percentage: percentage))
        if batteryHistory.count > maxHistorySamples {
            batteryHistory.removeFirst(batteryHistory.count - maxHistorySamples)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = isLaunchAtLoginEnabled()
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
