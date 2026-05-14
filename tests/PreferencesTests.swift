import XCTest
@testable import KeepAwakeCore

final class PreferencesTests: XCTestCase {
    var defaults: UserDefaults!
    var prefs: Preferences!

    override func setUp() {
        super.setUp()
        let suiteName = "KeepAwakeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        prefs = Preferences(defaults: defaults)
    }

    func testTargetSSIDDefaultsNil() {
        XCTAssertNil(prefs.targetSSID)
    }

    func testTargetSSIDRoundTrip() {
        prefs.targetSSID = "iPhone-Felipe"
        XCTAssertEqual(prefs.targetSSID, "iPhone-Felipe")
    }

    func testClearTargetSSID() {
        prefs.targetSSID = "x"
        prefs.targetSSID = nil
        XCTAssertNil(prefs.targetSSID)
    }

    func testDurationDefaultIsIndefinite() {
        XCTAssertEqual(prefs.duration, .indefinite)
    }

    func testDurationRoundTrip() {
        prefs.duration = .oneHour
        XCTAssertEqual(prefs.duration, .oneHour)
    }

    func testInvalidDurationFallsBackToIndefinite() {
        defaults.set("garbage", forKey: "duration")
        XCTAssertEqual(prefs.duration, .indefinite)
    }

    func testLaunchAtLoginDefaultsFalse() {
        XCTAssertFalse(prefs.launchAtLogin)
    }

    func testLaunchAtLoginRoundTrip() {
        prefs.launchAtLogin = true
        XCTAssertTrue(prefs.launchAtLogin)
    }

    func testKeepDisplayAwakeDefaultsFalse() {
        XCTAssertFalse(prefs.keepDisplayAwake)
    }

    func testKeepDisplayAwakeRoundTrip() {
        prefs.keepDisplayAwake = true
        XCTAssertTrue(prefs.keepDisplayAwake)
    }
}
