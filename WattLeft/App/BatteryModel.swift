import Foundation
import ServiceManagement
import SwiftUI

enum EnergyImpactMetric {
    case power
    case cpu

    var liveTitle: String {
        switch self {
        case .power:
            return "Energy Impact (live)"
        case .cpu:
            return "Activity (CPU)"
        }
    }
}

@MainActor
final class BatteryModel: ObservableObject {
    @Published private(set) var info: BatteryInfo = .empty
    @Published private(set) var launchAtLogin = false
    @Published private(set) var energyImpactApps: [EnergyImpactApp] = []
    @Published private(set) var energyImpactTotals: [EnergyImpactAppSummary] = []
    @Published private(set) var powerHistory: [PowerSample] = []
    @Published private(set) var energyImpactMetric: EnergyImpactMetric = .power

    private let reader = BatteryReader()
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    private let lastUnpluggedKey = "WattLeft.lastUnpluggedAt"
    private let lastOnACKey = "WattLeft.lastOnACPower"
    private var lastUnpluggedAt: Date?
    private var lastWasOnACPower: Bool?
    private var lastImpactSampleAt: Date?
    private var impactTotals: [String: Double] = [:]
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
        let now = Date()
        energyImpactApps = reader.readEnergyImpactApps()
        energyImpactMetric = .power
        updateImpactTotals(apps: energyImpactApps, isOnACPower: nextInfo.isOnACPower, now: now)
        updatePowerHistory(watts: nextInfo.powerConsumptionWatts, isOnACPower: nextInfo.isOnACPower)
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

    private func updatePowerHistory(watts: Double?, isOnACPower: Bool) {
        if isOnACPower {
            if !powerHistory.isEmpty {
                powerHistory = []
            }
            return
        }

        guard let watts, watts > 0 else { return }

        let now = Date()
        if let last = powerHistory.last,
           Calendar.current.isDate(last.timestamp, equalTo: now, toGranularity: .minute),
           abs(last.watts - watts) < 0.05 {
            return
        }

        powerHistory.append(PowerSample(timestamp: now, watts: watts))
        if powerHistory.count > maxHistorySamples {
            powerHistory.removeFirst(powerHistory.count - maxHistorySamples)
        }
    }

    private func updateImpactTotals(apps: [EnergyImpactApp], isOnACPower: Bool, now: Date) {
        if isOnACPower {
            if !impactTotals.isEmpty || !energyImpactTotals.isEmpty {
                impactTotals = [:]
                energyImpactTotals = []
            }
            lastImpactSampleAt = nil
            return
        }

        guard let lastImpactSampleAt else {
            self.lastImpactSampleAt = now
            return
        }

        let interval = now.timeIntervalSince(lastImpactSampleAt)
        guard interval > 0 else {
            self.lastImpactSampleAt = now
            return
        }

        let clampedInterval = min(interval, 300)
        let minutes = clampedInterval / 60.0

        for app in apps {
            impactTotals[app.name, default: 0] += app.impact * minutes
        }

        self.lastImpactSampleAt = now
        energyImpactTotals = impactTotals
            .map { EnergyImpactAppSummary(name: $0.key, totalImpact: $0.value) }
            .sorted { $0.totalImpact > $1.totalImpact }
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
