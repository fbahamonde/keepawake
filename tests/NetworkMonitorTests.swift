import XCTest
@testable import KeepAwakeCore

final class MockSSIDProvider: SSIDProvider {
    var current: String?
    func currentSSID() -> String? { current }
}

final class NetworkMonitorTests: XCTestCase {
    var clock: MockClock!
    var provider: MockSSIDProvider!
    var monitor: NetworkMonitor!
    var events: [NetworkEvent]!

    override func setUp() {
        super.setUp()
        clock = MockClock(start: Date(timeIntervalSince1970: 1_700_000_000))
        provider = MockSSIDProvider()
        events = []
        monitor = NetworkMonitor(
            ssidProvider: provider,
            clock: clock,
            gracePeriod: 60,
            nilToleranceCount: 3,
            onEvent: { [weak self] in self?.events.append($0) }
        )
    }

    func testNoTargetEmitsMatch() {
        monitor.setTarget(nil)
        provider.current = "AnyNetwork"
        monitor.tick()
        XCTAssertEqual(events.last, .matched(ssid: "AnyNetwork"))
    }

    func testMatchingTargetEmitsMatch() {
        monitor.setTarget("Home")
        provider.current = "Home"
        monitor.tick()
        XCTAssertEqual(events.last, .matched(ssid: "Home"))
    }

    func testMismatchStartsGrace() {
        monitor.setTarget("Home")
        provider.current = "Cafe"
        monitor.tick()
        guard case .graceStarted(let ssid, let deadline) = events.last else {
            return XCTFail("expected graceStarted, got \(String(describing: events.last))")
        }
        XCTAssertEqual(ssid, "Cafe")
        XCTAssertEqual(deadline, clock.current.addingTimeInterval(60))
    }

    func testMismatchSustained60sEmitsPaused() {
        monitor.setTarget("Home")
        provider.current = "Cafe"
        monitor.tick()
        clock.advance(by: 61)
        monitor.tick()
        XCTAssertEqual(events.last, .paused)
    }

    func testMatchReturnsDuringGraceCancels() {
        monitor.setTarget("Home")
        provider.current = "Cafe"
        monitor.tick()
        clock.advance(by: 30)
        provider.current = "Home"
        monitor.tick()
        XCTAssertEqual(events.last, .matched(ssid: "Home"))
    }

    func testMatchAfterPausedEmitsResumed() {
        monitor.setTarget("Home")
        provider.current = "Cafe"
        monitor.tick()
        clock.advance(by: 61)
        monitor.tick()
        XCTAssertEqual(events.last, .paused)
        provider.current = "Home"
        monitor.tick()
        XCTAssertEqual(events.last, .resumed(ssid: "Home"))
    }

    func testNilSSIDTreatedAsUnknownBelowTolerance() {
        monitor.setTarget("Home")
        provider.current = nil
        monitor.tick()
        monitor.tick()
        XCTAssertTrue(events.allSatisfy { if case .unknown = $0 { return true } else { return false } })
    }

    func testNilSSIDExceedingToleranceTreatedAsMismatch() {
        monitor.setTarget("Home")
        provider.current = nil
        monitor.tick()
        monitor.tick()
        monitor.tick()
        guard case .graceStarted = events.last else {
            return XCTFail("expected graceStarted after nil tolerance, got \(String(describing: events.last))")
        }
    }

    func testChangingTargetDuringGraceReevaluates() {
        monitor.setTarget("Home")
        provider.current = "Cafe"
        monitor.tick()
        XCTAssertEqual(events.count, 1)
        monitor.setTarget("Cafe")
        XCTAssertEqual(events.last, .matched(ssid: "Cafe"))
    }

    func testClearingTargetWhilePausedEmitsResumed() {
        monitor.setTarget("Home")
        provider.current = "Cafe"
        monitor.tick()
        clock.advance(by: 61)
        monitor.tick()
        XCTAssertEqual(events.last, .paused)
        monitor.setTarget(nil)
        XCTAssertEqual(events.last, .resumed(ssid: "Cafe"))
    }
}
