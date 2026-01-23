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
}
