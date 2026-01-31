import XCTest
import IOKit.ps
@testable import WattLeft

final class BatteryReaderTests: XCTestCase {
    func testBatteryInfoParsingOnBattery() {
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 50,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSDesignCapacityKey as String: 100,
            "Cycle Count": 320,
            kIOPSBatteryHealthConditionKey as String: "Normal",
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false,
            kIOPSTimeToEmptyKey as String: 90
        ]

        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.percentage, 50)
        XCTAssertEqual(info?.timeRemainingMinutes, 90)
        XCTAssertEqual(info?.healthPercentage, 100)
        XCTAssertEqual(info?.cycleCount, 320)
        XCTAssertEqual(info?.condition, "Normal")
        XCTAssertEqual(info?.isCharging, false)
        XCTAssertEqual(info?.isOnACPower, false)
    }

    func testBatteryInfoParsingOnACCharging() {
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 80,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSDesignCapacityKey as String: 120,
            kIOPSPowerSourceStateKey as String: kIOPSACPowerValue,
            kIOPSIsChargingKey as String: true,
            kIOPSTimeToFullChargeKey as String: 25,
            kIOPSBatteryHealthKey as String: "Good"
        ]

        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.percentage, 80)
        XCTAssertEqual(info?.timeRemainingMinutes, 25)
        XCTAssertEqual(info?.healthPercentage, 83)
        XCTAssertEqual(info?.cycleCount, nil)
        XCTAssertEqual(info?.condition, "Good")
        XCTAssertEqual(info?.isCharging, true)
        XCTAssertEqual(info?.isOnACPower, true)
    }

    func testBatteryConditionFallsBackWhenBlank() {
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 40,
            kIOPSMaxCapacityKey as String: 70,
            kIOPSDesignCapacityKey as String: 100,
            kIOPSBatteryHealthConditionKey as String: " ",
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false
        ]

        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.healthPercentage, 70)
        XCTAssertEqual(info?.condition, "Fair")
    }

    func testPowerModeParsing() {
        let output = """
        Battery Power:
         power        1
         powermode    2
        """
        XCTAssertEqual(BatteryReader.powerMode(fromPMSetOutput: output), "High Power")

        let outputAuto = "powermode 0"
        XCTAssertEqual(BatteryReader.powerMode(fromPMSetOutput: outputAuto), "Automatic")

        let outputLow = "powermode\\t1"
        XCTAssertEqual(BatteryReader.powerMode(fromPMSetOutput: outputLow), "Low Power")
    }

    func testEnergyImpactParsing() {
        let output = """
        Processes: 520 total, 2 running, 518 sleeping, 3052 threads
        Load Avg: 1.11, 1.23, 1.45
        PID    COMMAND      POWER
        120    Safari       35.1
        210    WindowServer 12.4
        432    Note App     3.2
        77     idle_task    0.0
        """

        let apps = BatteryReader.energyImpactApps(fromTopOutput: output)
        XCTAssertEqual(apps.count, 3)
        XCTAssertEqual(apps.first?.name, "Safari")
        XCTAssertEqual(apps.first?.impact, 35.1)
        XCTAssertEqual(apps[1].name, "WindowServer")
        XCTAssertEqual(apps[2].name, "Note App")
    }

    func testPowerConsumptionFromRegistry() {
        let registry: [String: Any] = [
            "InstantAmperage": -1500,
            "Voltage": 12000
        ]

        let watts = BatteryReader.powerConsumptionWatts(fromRegistry: registry)
        XCTAssertNotNil(watts)
        XCTAssertEqual(watts ?? 0, 18.0, accuracy: 0.01)
    }
    
    // MARK: - Percentage Calculation Tests
    
    func testBatteryPercentageRoundingDown() {
        // Test case: 48.4% should round down to 48%
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 484,
            kIOPSMaxCapacityKey as String: 1000,
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false
        ]
        
        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.percentage, 48, "48.4% should round down to 48%")
    }
    
    func testBatteryPercentageRoundingUp() {
        // Test case: 48.5% should round up to 49%
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 485,
            kIOPSMaxCapacityKey as String: 1000,
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false
        ]
        
        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.percentage, 49, "48.5% should round up to 49%")
    }
    
    func testBatteryPercentageExactValue() {
        // Test case: Exact percentage should remain the same
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 75,
            kIOPSMaxCapacityKey as String: 100,
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false
        ]
        
        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.percentage, 75, "75% should remain 75%")
    }
    
    func testBatteryPercentageWithLargeCapacity() {
        // Test case: Large capacity values with decimal result
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 4867,
            kIOPSMaxCapacityKey as String: 5000,
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false
        ]
        
        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        // 4867/5000 = 0.9734 = 97.34% -> rounds to 97%
        XCTAssertEqual(info?.percentage, 97, "97.34% should round to 97%")
    }
    
    func testBatteryPercentageNearHundred() {
        // Test case: 99.6% should round to 100%
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 498,
            kIOPSMaxCapacityKey as String: 500,
            kIOPSPowerSourceStateKey as String: kIOPSACPowerValue,
            kIOPSIsChargingKey as String: true
        ]
        
        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        // 498/500 = 0.996 = 99.6% -> rounds to 100%
        XCTAssertEqual(info?.percentage, 100, "99.6% should round to 100%")
    }
    
    func testBatteryPercentageLowCharge() {
        // Test case: Low charge with rounding
        let description: [String: Any] = [
            kIOPSTypeKey as String: kIOPSInternalBatteryType,
            kIOPSCurrentCapacityKey as String: 27,
            kIOPSMaxCapacityKey as String: 1000,
            kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey as String: false
        ]
        
        let info = BatteryReader.batteryInfo(from: description)
        XCTAssertNotNil(info)
        // 27/1000 = 0.027 = 2.7% -> rounds to 3%
        XCTAssertEqual(info?.percentage, 3, "2.7% should round to 3%")
    }
    
    func testBatteryPercentageConsistencyWithFluctuation() {
        // Test that small capacity fluctuations don't cause percentage jumps
        let descriptions: [[String: Any]] = [
            [
                kIOPSTypeKey as String: kIOPSInternalBatteryType,
                kIOPSCurrentCapacityKey as String: 4899,
                kIOPSMaxCapacityKey as String: 5000,
                kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
                kIOPSIsChargingKey as String: false
            ],
            [
                kIOPSTypeKey as String: kIOPSInternalBatteryType,
                kIOPSCurrentCapacityKey as String: 4898,
                kIOPSMaxCapacityKey as String: 5000,
                kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
                kIOPSIsChargingKey as String: false
            ],
            [
                kIOPSTypeKey as String: kIOPSInternalBatteryType,
                kIOPSCurrentCapacityKey as String: 4897,
                kIOPSMaxCapacityKey as String: 5000,
                kIOPSPowerSourceStateKey as String: kIOPSBatteryPowerValue,
                kIOPSIsChargingKey as String: false
            ]
        ]
        
        let percentages = descriptions.compactMap { BatteryReader.batteryInfo(from: $0)?.percentage }
        XCTAssertEqual(percentages.count, 3)
        // All should be 98% (97.98%, 97.96%, 97.94%)
        XCTAssertEqual(percentages[0], 98)
        XCTAssertEqual(percentages[1], 98)
        XCTAssertEqual(percentages[2], 98)
    }
}
